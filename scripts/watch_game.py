#!/usr/bin/env python3
"""Watch a game running under the hub and append what matters to one log file, so a session can read it later.

usage: scripts/watch_game.py EXE [--interval SECONDS] [--idle-exit MINUTES] [--max-hours HOURS]

Writes `$HUB_ROOT/Hub/Logs/watch/<exe>-<date>.log` and points `<exe>-latest.log` at it. Each line starts with a time.
It records, once per distinct message:
  * the game process starting and stopping, with its exit time;
  * new `err:`/`warn:` lines (DXMT) and Wine `err:` lines in the newest Hub/Logs/<launcher>-*.log;
  * new lines of the game's DXMT log (`Hub/Logs/dxmt-<game>/`) and mtld3d log (`Library/Epic/<game>/mtld3d-logs/`);
  * new crash reports in ~/Library/Logs/DiagnosticReports that mention the game or Wine;
and every 30 s a status line: game RSS and CPU, swap used, free memory percentage, counts of the noisy messages.
Polls with plain file reads (no subprocess per poll except `ps`/`sysctl`), so it costs almost no CPU.
It exits when the game has been gone `--idle-exit` minutes (default 10), when it never started within 60 minutes, or after
`--max-hours` (default 6). Stop it early with `kill $(cat <log dir>/<exe>.pid)`.
"""
import argparse
import os
import re
import signal
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(os.environ.get("HUB_ROOT", "/Volumes/ExT2/GameHub"))
LOGS = ROOT / "Hub/Logs"
REPORTS = Path.home() / "Library/Logs/DiagnosticReports"
NOISE = re.compile(r"fault outside mtld3d\.so|mtld3d\.so return addrs|Unknown interface query|MakeWindowAssociation|maxtessfactor|Unsupported border color|Maximum supported feature level|Using feature level|Failed to set Metal cache path")
INTERESTING = re.compile(r"^(err|warn|info):|fault outside|exception|page fault|unhandled|crash", re.I)
GUID = re.compile(r"[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}")


def stamp() -> str:
    return time.strftime("%H:%M:%S")


def run(*cmd: str) -> str:
    """Return the stdout of `cmd`, or an empty string when it fails."""
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=10).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


class Tail:
    """Reads the lines appended to a file since the last call; restarts from the top when the file was replaced or truncated."""

    def __init__(self) -> None:
        self.path: Path | None = None
        self.inode = -1
        self.pos = 0

    def new_lines(self, path: Path | None, from_start: bool, marker: bytes = b"") -> list[str]:
        if path is None or not path.is_file():
            return []
        st = path.stat()
        if path != self.path or st.st_ino != self.inode or st.st_size < self.pos:
            first = self.path is None
            self.path, self.inode = path, st.st_ino
            self.pos = 0 if (from_start or not first) else st.st_size
            if marker and self.pos == 0:   # an appended log holds many runs: start at the last one
                self.pos = max(path.read_bytes().rfind(marker), 0)
        if st.st_size <= self.pos:
            return []
        with path.open("rb") as f:
            f.seek(self.pos)
            data = f.read(st.st_size - self.pos)
        self.pos = st.st_size
        return data.decode("utf-8", "replace").splitlines()


def newest(directory: Path, pattern: str) -> Path | None:
    files = [p for p in directory.glob(pattern) if p.is_file()]
    return max(files, key=lambda p: p.stat().st_mtime) if files else None


def newest_glob(base: Path, pattern: str) -> Path | None:
    """Return the most recently modified file under `base` that matches the glob `pattern`, or None."""
    files = [p for p in base.glob(pattern) if p.is_file()]
    return max(files, key=lambda p: p.stat().st_mtime) if files else None


def game_process(exe: str) -> tuple[int, str, int, float] | None:
    """Return (pid, elapsed, rss MB, cpu %) of the newest process whose command contains `exe`, or None."""
    rows = []
    for line in run("ps", "-axo", "pid=,etime=,rss=,pcpu=,command=").splitlines():
        parts = line.split(None, 4)
        if len(parts) == 5 and int(parts[0]) != os.getpid() and exe.lower() in parts[4].lower() and not re.search(r"x87sidecar|watch_game|grep|ps -axo", parts[4]):
            rows.append(parts)
    if not rows:
        return None
    pid, etime, rss, cpu, _ = rows[-1]
    return int(pid), etime, int(rss) // 1024, float(cpu)


def swap_used_mb() -> str:
    m = re.search(r"used = ([\d.]+)M", run("sysctl", "-n", "vm.swapusage"))
    return m.group(1) if m else "?"


def free_memory_percent() -> str:
    m = re.search(r"free percentage: (\d+)%", run("memory_pressure"))
    return m.group(1) if m else "?"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("exe")
    ap.add_argument("--interval", type=float, default=5.0)
    ap.add_argument("--idle-exit", type=float, default=10.0)
    ap.add_argument("--max-hours", type=float, default=6.0)
    args = ap.parse_args()
    exe_stem = args.exe.removesuffix(".exe")
    game = exe_stem.lower()
    out_dir = LOGS / "watch"
    out_dir.mkdir(parents=True, exist_ok=True)
    log_path = out_dir / f"{game}-{time.strftime('%Y%m%d-%H%M%S')}.log"
    latest = out_dir / f"{game}-latest.log"
    pidfile = out_dir / f"{game}.pid"
    pidfile.write_text(str(os.getpid()))
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))   # run the cleanup in `finally` when stopped with kill
    latest.unlink(missing_ok=True)
    latest.symlink_to(log_path.name)
    out = log_path.open("a", buffering=1)

    def emit(text: str) -> None:
        out.write(f"{stamp()} {text}\n")

    sources = {"epic": Tail(), "dxmt": Tail(), "mtld3d": Tail()}
    seen: set[tuple[str, str]] = set()
    noisy: dict[str, int] = {}
    seen_reports = {p.name for p in REPORTS.glob("*.ips")} if REPORTS.is_dir() else set()
    started = time.time()
    last_status = 0.0
    last_seen_running = None
    was_running = False
    emit(f"watching {args.exe}; log {log_path}")

    def digest(source: str, lines: list[str]) -> None:
        for line in lines:
            if not INTERESTING.search(line):
                continue
            key = GUID.sub("<guid>", re.sub(r"ps_[0-9a-f_]+", "ps_<hash>", line)).strip()
            if NOISE.search(line):
                noisy[key[:60]] = noisy.get(key[:60], 0) + 1
                continue
            if (source, key) in seen:
                continue
            seen.add((source, key))
            emit(f"[{source}] {line.strip()[:300]}")

    try:
        while time.time() - started < args.max_hours * 3600:
            proc = game_process(args.exe)
            now = time.time()
            if proc and not was_running:
                emit(f"GAME STARTED pid {proc[0]}")
                for name in ("dxmt", "mtld3d"):   # new game process: read its logs from the top
                    sources[name].path = None
            if was_running and not proc:
                emit("GAME STOPPED")
            was_running = proc is not None
            if proc:
                last_seen_running = now

            digest("epic", sources["epic"].new_lines(newest(LOGS, "epic-*.log"), from_start=False))
            digest("dxmt", sources["dxmt"].new_lines(newest_glob(LOGS, f"dxmt-*/{exe_stem}_d3d11.log"), from_start=True, marker=b"---- log opened ----"))
            digest("mtld3d", sources["mtld3d"].new_lines(newest_glob(ROOT / "Library", f"*/*/mtld3d-logs/{exe_stem}-*.log"), from_start=True))

            if REPORTS.is_dir():
                for p in sorted(REPORTS.glob("*.ips"), key=lambda p: p.stat().st_mtime):
                    if p.name in seen_reports:
                        continue
                    seen_reports.add(p.name)
                    head = p.read_text(errors="replace")[:400]
                    if re.search(rf"wine|{game}", head, re.I):
                        emit(f"[crash-report] {p.name}")

            if now - last_status >= 30:
                last_status = now
                if proc:
                    emit(f"status pid {proc[0]} up {proc[1]} rss {proc[2]} MB cpu {proc[3]:.0f}% | swap {swap_used_mb()} MB | free mem {free_memory_percent()}% | noise {sum(noisy.values())}")
                else:
                    emit(f"status game not running | swap {swap_used_mb()} MB | free mem {free_memory_percent()}%")
            gone_for = now - last_seen_running if last_seen_running else None
            if (gone_for is not None and gone_for >= args.idle_exit * 60) or (gone_for is None and now - started > 3600):
                emit("exiting: game not running")
                break
            time.sleep(args.interval)
    finally:
        if noisy:
            emit("noisy messages (count): " + "; ".join(f"{v}x {k}" for k, v in sorted(noisy.items(), key=lambda kv: -kv[1])[:8]))
        emit("watcher stopped")
        pidfile.unlink(missing_ok=True)
        out.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
