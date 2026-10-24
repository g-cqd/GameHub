#!/usr/bin/env python3
"""Watch a game running under the hub and append what matters to one log file, so a session can read it later.

usage: scripts/watch_game.py EXE [--interval SECONDS] [--idle-exit MINUTES] [--max-hours HOURS] [--shots SECONDS]

Writes `$HUB_ROOT/Hub/Logs/watch/<exe>-<date>.log` and points `<exe>-latest.log` at it. Each line starts with a time.
It records, once per distinct message:
  * the game process starting and stopping, with its exit time;
  * new `err:`/`warn:` lines (DXMT) and Wine `err:` lines in the newest Hub/Logs/<launcher>-*.log;
  * new lines of the game's DXMT log (`Hub/Logs/dxmt-<game>/`) and mtld3d log (`Library/Epic/<game>/mtld3d-logs/`);
  * new crash reports in ~/Library/Logs/DiagnosticReports that mention the game or Wine;
and every 30 s a status line: game RSS and CPU, swap used, free memory percentage, disk MB/s of the external volume (disk16)
and the internal one (disk0), page-in/swap-in/swap-out MB/s, and the count of noisy messages.
Polls with plain file reads (no subprocess per poll except `ps`/`sysctl`), so it costs almost no CPU.
With `--shots N` it also saves a downscaled screenshot every N seconds to `watch/shots/` (newest 150 kept) and logs a
`[screen]` line, with a copy in `shots/events/`, when more than 0.2 % of the pixels are magenta or more than 60 % are near white.
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


def disk_totals(*disks: str) -> dict[str, float]:
    """Return total MB transferred since boot (reads plus writes) for each of `disks`, e.g. disk16."""
    lines = run("iostat", "-Id", *disks).splitlines()
    names = lines[0].split() if lines else []
    values = lines[2].split() if len(lines) > 2 else []
    totals = {}
    for i, name in enumerate(names):
        if len(values) >= 3 * (i + 1):
            totals[name] = float(values[3 * i + 2])
    return totals


def vm_counters() -> dict[str, int]:
    """Return the vm_stat counters (Pageins, Swapins, Swapouts, ...) as integers."""
    out = {}
    for line in run("vm_stat").splitlines():
        m = re.match(r'"?([A-Za-z ]+?)"?:\s+(\d+)\.', line)
        if m:
            out[m.group(1)] = int(m.group(2))
    return out


def read_bmp_fractions(path: Path) -> tuple[float, float]:
    """Return (magenta fraction, near-white fraction) of an uncompressed 24- or 32-bit BMP, sampling every 2nd pixel."""
    data = path.read_bytes()
    offset = int.from_bytes(data[10:14], "little")
    width = int.from_bytes(data[18:22], "little", signed=True)
    height = abs(int.from_bytes(data[22:26], "little", signed=True))
    bytes_per_pixel = int.from_bytes(data[28:30], "little") // 8
    if bytes_per_pixel not in (3, 4) or width <= 0:
        return 0.0, 0.0
    stride = (width * bytes_per_pixel + 3) & ~3
    magenta = white = total = 0
    for y in range(0, height, 2):
        row = data[offset + y * stride: offset + y * stride + width * bytes_per_pixel]
        for x in range(0, width * bytes_per_pixel - 2, 2 * bytes_per_pixel):
            b, g, r = row[x], row[x + 1], row[x + 2]
            total += 1
            if r > 170 and b > 170 and g < 90:
                magenta += 1
            elif r > 235 and g > 235 and b > 235:
                white += 1
    return (magenta / total, white / total) if total else (0.0, 0.0)


def take_shot(shots: Path, keep: int, emit) -> None:
    """Save a downscaled screenshot to `shots`, keep the newest `keep`, and keep a copy in `shots/events` when it shows magenta or a white screen."""
    name = f"{time.strftime('%H%M%S')}.jpg"
    full, small, bmp = shots / "full.png", shots / name, shots / "probe.bmp"
    if subprocess.run(["screencapture", "-x", "-t", "png", str(full)], capture_output=True).returncode != 0 or not full.exists():
        return
    run("sips", "-Z", "1280", "-s", "format", "jpeg", "-s", "formatOptions", "60", str(full), "--out", str(small))
    run("sips", "-Z", "480", "-s", "format", "bmp", str(full), "--out", str(bmp))
    full.unlink(missing_ok=True)
    try:
        magenta, white = read_bmp_fractions(bmp)
    except (OSError, ValueError, IndexError):
        magenta = white = 0.0
    bmp.unlink(missing_ok=True)
    if magenta > 0.002 or white > 0.6:
        (shots / "events").mkdir(exist_ok=True)
        if small.exists():
            (shots / "events" / name).write_bytes(small.read_bytes())
        emit(f"[screen] {name}: magenta {magenta * 100:.2f}% white {white * 100:.0f}% of pixels (copy in shots/events/)")
    old = sorted(p for p in shots.glob("*.jpg"))[:-keep]
    for p in old:
        p.unlink(missing_ok=True)


def free_memory_percent() -> str:
    m = re.search(r"free percentage: (\d+)%", run("memory_pressure"))
    return m.group(1) if m else "?"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("exe")
    ap.add_argument("--interval", type=float, default=5.0)
    ap.add_argument("--idle-exit", type=float, default=10.0)
    ap.add_argument("--max-hours", type=float, default=6.0)
    ap.add_argument("--shots", type=float, default=0.0, help="seconds between screenshots while the game runs (0 = off)")
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
    last_shot = 0.0
    shots_dir = out_dir / "shots"
    shots_dir.mkdir(exist_ok=True)
    prev_io: dict[str, float] = {}
    prev_vm: dict[str, int] = {}
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

            if proc and args.shots and now - last_shot >= args.shots:
                last_shot = now
                take_shot(shots_dir, 150, emit)

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
                io, vm = disk_totals("disk16", "disk0"), vm_counters()
                span = now - last_status if last_status else 0
                rates = ""
                if span and prev_io and prev_vm:
                    mb = {d: (io.get(d, 0) - prev_io.get(d, 0)) / span for d in io}
                    pages = {k: (vm.get(k, 0) - prev_vm.get(k, 0)) * 16 / 1024 / span for k in ("Pageins", "Swapins", "Swapouts")}
                    rates = f" | disk16 {mb.get('disk16', 0):.0f} MB/s disk0 {mb.get('disk0', 0):.0f} MB/s | pagein {pages['Pageins']:.0f} swapin {pages['Swapins']:.0f} swapout {pages['Swapouts']:.0f} MB/s"
                prev_io, prev_vm = io, vm
                last_status = now
                if proc:
                    emit(f"status pid {proc[0]} up {proc[1]} rss {proc[2]} MB cpu {proc[3]:.0f}% | swap {swap_used_mb()} MB | free mem {free_memory_percent()}%{rates} | noise {sum(noisy.values())}")
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
