#!/usr/bin/env python3
"""Read-only: list processes that belong to the given Wine prefix.

usage: prefix_procs.py PREFIX
stdout lines:  HIT<TAB>pid<TAB>command   a process of PREFIX
               WARN<TAB>text            an indeterminate process (reported, never blocks)
               NONE                     printed (with exit 1) only when the scan finished cleanly and found no HIT
exit 0: at least one HIT
exit 1: clean scan, no HIT (the line NONE is printed; callers must require it)
exit 3: anything went wrong (process table or lsof unreadable, any exception): treat as "running"

1. A process matches when the WINEPREFIX variable of its *environment* (the part of `ps eww` output after
   the argv) is exactly PREFIX (trailing slashes ignored) or names the same directory (st_dev/st_ino, e.g. a
   symlink alias). Processes of any other prefix never match. The argv is taken from `ps -ww -o command=`, so
   a command line that merely mentions "WINEPREFIX=..." is not a match.
2. Windows-image processes (winedevice.exe, EABackgroundService.exe, ...) show no environment at all. A process
   that looks like Wine (wine, x87sidecar, *.exe, C:\...) and whose environment is unreadable is examined with
   `lsof -p`: if it maps/opens files in PREFIX's server directory (/tmp/.wine-<uid>/server-<dev>-<ino>) or inside
   PREFIX it is a HIT; if it is tied to another server directory it is ignored (leftovers of other prefixes
   must not block forever); otherwise it is reported as WARN and does not block.
This process, its ancestors and its descendants are ignored.
"""
import os
import re
import subprocess
import sys

ENV_RE = re.compile(r"(?:^| )WINEPREFIX=(.*?)(?= [A-Za-z_][A-Za-z0-9_]*=|$)")


def ps(args):
    return subprocess.run(["/bin/ps"] + args, stdout=subprocess.PIPE,
                          stderr=subprocess.DEVNULL, check=False).stdout.decode("utf-8", "replace")


def ident(path):
    try:
        st = os.stat(path)
        return (st.st_dev, st.st_ino)
    except OSError:
        return None


WINEISH = re.compile(r"(wine|x87sidecar|\.exe\b|^[A-Za-z]:\\)", re.I)
SERVER_RE = re.compile(r"/\.wine-\d+/server-([0-9a-f]+-[0-9a-f]+)(?:/|$)")


def classify_envless(cands, rows, prefix, prefix_id):
    """Examine Wine-looking processes without a readable environment. -> (hits, warnings)."""
    if not cands:
        return [], []
    ours = None
    if prefix_id is not None:
        ours = "%x-%x" % prefix_id
    real_prefix = os.path.realpath(prefix)
    r = subprocess.run(["/usr/sbin/lsof", "-p", ",".join(str(p) for p in cands), "-Fpn"],
                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=120)
    if r.returncode not in (0, 1):
        raise RuntimeError("lsof -p failed with status %d" % r.returncode)
    names = {}
    cur = None
    for line in r.stdout.decode("utf-8", "replace").splitlines():
        if line.startswith("p"):
            cur = int(line[1:])
            names.setdefault(cur, [])
        elif line.startswith("n") and cur is not None:
            names[cur].append(line[1:])
    hits, warns = [], []
    for pid in cands:
        if pid not in names:
            if ps(["-p", str(pid), "-o", "pid="]).strip():
                warns.append("pid %d (%s): lsof shows nothing for it" % (pid, rows[pid][1][:60]))
            continue                                  # else: it went away
        ids = set()
        inside = False
        for n in names[pid]:
            m = SERVER_RE.search(n)
            if m:
                ids.add(m.group(1))
            if n == real_prefix or n.startswith(real_prefix + "/") or n == prefix or n.startswith(prefix + "/"):
                inside = True
        if inside or (ours is not None and ours in ids):
            hits.append((pid, "env unreadable, tied to the prefix by its open/mapped files: " + rows[pid][1][:80]))
        elif ids:
            continue                                  # provably another prefix's server directory
        else:
            warns.append("pid %d (%s): Wine-looking, environment and open files do not say which prefix" % (pid, rows[pid][1][:60]))
    return hits, warns


def main(argv):
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 3
    prefix = argv[1].rstrip("/") or "/"
    prefix_id = ident(prefix)
    try:
        table = subprocess.run(["/bin/ps", "eww", "-axo", "pid,ppid,command"],
                               stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=True)
    except (OSError, subprocess.CalledProcessError):
        return 3
    rows = {}
    for line in table.stdout.decode("utf-8", "replace").splitlines()[1:]:
        parts = line.strip().split(None, 2)
        if len(parts) < 2 or not parts[0].isdigit() or not parts[1].isdigit():
            continue
        rows[int(parts[0])] = (int(parts[1]), parts[2] if len(parts) > 2 else "")
    if not rows:
        return 3
    me = os.getpid()
    ignore = {me}
    p = me
    while p in rows and rows[p][0] > 1 and rows[p][0] not in ignore:   # ancestors (never launchd)
        p = rows[p][0]
        ignore.add(p)
    children = {}
    for pid, (ppid, _) in rows.items():
        children.setdefault(ppid, []).append(pid)
    todo = [me]
    while todo:                          # descendants of this process (ps itself, subshells)
        for c in children.get(todo.pop(), []):
            if c not in ignore:
                ignore.add(c)
                todo.append(c)
    hits = []
    for pid, (_, full) in sorted(rows.items()):
        if pid in ignore or "WINEPREFIX=" not in full:
            continue
        argv_only = ps(["-ww", "-p", str(pid), "-o", "command="]).strip()
        if not argv_only and not ps(["-p", str(pid), "-o", "pid="]).strip():
            continue                     # the process went away
        env_part = full[len(argv_only):] if argv_only and full.startswith(argv_only) else full
        for m in ENV_RE.finditer(env_part):
            val = m.group(1).strip()
            vnorm = val.rstrip("/") or "/"
            same = vnorm == prefix
            if not same and prefix_id is not None and os.path.isdir(val):
                same = ident(val) == prefix_id
            if same:
                hits.append((pid, argv_only or full))
                break
    cands = [pid for pid, (_, full) in sorted(rows.items())
             if pid not in ignore and "WINEPREFIX=" not in full and WINEISH.search(full)]
    ehits, warns = classify_envless(cands, rows, prefix, prefix_id)
    for pid, cmd in hits:
        print("HIT\t%d\t%s" % (pid, cmd[:120]))
    for pid, why in ehits:
        print("HIT\t%d\t%s" % (pid, why))
    for w in warns:
        print("WARN\t" + w)
    if hits or ehits:
        return 0
    print("NONE")
    return 1


if __name__ == "__main__":
    try:
        rc = main(sys.argv)
    except BaseException as exc:                      # fail closed: an error is never "no processes"
        print("ERROR\t%s: %s" % (type(exc).__name__, exc))
        rc = 3
    sys.exit(rc)
