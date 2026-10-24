#!/usr/bin/env python3
"""Per-run segment timings of EAGEP from EAGEPVerbose.log (+ BGS createProcess / Client connected)."""
import re, sys, datetime
LOG = "/Volumes/ExT2/GameHub/Prefix/drive_c/ProgramData/EA Desktop/Logs/"
MARK = [("A", "EAGEP.rcc.enc"), ("B", "cacertificates.rcc.enc"), ("C", "setNormalMode"),
        ("D", "[global-io-0]"), ("E", "[global-io-1]"), ("F", "[PlatformNetworkMonitor]"),
        ("G", "machash"), ("H", "Request Url=[https://statsigapi"), ("I", "ExperimentsStatus=loaded"),
        ("J", "Ipc Server listening"), ("K", "target: [localhost"), ("L", "connected to [localhost")]
def ts(line):
    m = re.search(r"\[(\d{4}-\d\d-\d\dT[\d:.]+)Z\]", line)
    return datetime.datetime.fromisoformat(m.group(1)).replace(tzinfo=datetime.timezone.utc).timestamp() if m else None
runs = {}
for line in open(LOG + "EAGEPVerbose.log", errors="replace"):
    m = re.search(r"PID:\s+(\d+)", line)
    if not m: continue
    t = ts(line)
    for k, s in MARK:
        if s in line:
            r = runs.setdefault((m.group(1), t if k == "A" else None), None)
    pid = m.group(1)
    for k, s in MARK:
        if s in line:
            if k == "A": runs[pid + "@%.0f" % t] = {"A": t}; cur = pid + "@%.0f" % t
            else:
                key = [x for x in runs if isinstance(x, str) and x.startswith(pid + "@")]
                if key: runs[key[-1]].setdefault(k, t)
creates, conns = [], []
for line in open(LOG + "EABackgroundService.log", errors="replace"):
    if "createProcess" in line and "EAGEP" in line: creates.append(ts(line))
    if "Client connected [EAGEP.exe]" in line: conns.append(ts(line))
since = float(sys.argv[1]) if len(sys.argv) > 1 else 0
keys = "ABCDEFGHIJKL"
print("start(UTC)        cp->A " + " ".join(f"{a}{b}".rjust(5) for a, b in zip(keys, keys[1:])) + "  A->L  cp->conn")
for k, r in sorted(((k, v) for k, v in runs.items() if isinstance(k, str)), key=lambda x: x[1]["A"]):
    if r["A"] < since or "L" not in r: continue
    cp = max([c for c in creates if c <= r["A"] and r["A"] - c < 10], default=None)
    cn = min([c for c in conns if c >= r["L"] - 1], default=None)
    segs = []
    for a, b in zip(keys, keys[1:]):
        segs.append(f"{(r[b]-r[a])*1000:5.0f}" if a in r and b in r else "    -")
    print(datetime.datetime.utcfromtimestamp(r["A"]).strftime("%m-%d %H:%M:%S"),
          f"{(r['A']-cp)*1000:6.0f}" if cp else "     -", " ".join(segs), f"{(r['L']-r['A'])*1000:5.0f}",
          f"{(cn-cp)*1000:6.0f}" if cp and cn else "")
