#!/usr/bin/env python3
"""Run EAGEP with the clone runtime N times (sequentially) and report start -> 'Client connected [EAGEP.exe]'."""
import subprocess, sys, re, datetime
BGS = "/Volumes/ExT2/GameHub/Prefix/drive_c/ProgramData/EA Desktop/Logs/EABackgroundService.log"
n = int(sys.argv[1])
for i in range(n):
    out = subprocess.run(["/Volumes/ExT2/GameHub/work/wine-fontperf/gep-run-fontperf.sh", f"/tmp/fp-gep-{i}.log"],
                         capture_output=True, text=True).stdout
    start = float(re.search(r"start_epoch=([0-9.]+)", out).group(1))
    hits = []
    for line in open(BGS, errors="replace"):
        if "Client connected [EAGEP.exe]" in line or "EAGEP didn't respond" in line:
            ts = re.search(r"\[(\d{4}-\d\d-\d\dT[\d:.]+)Z\]", line).group(1)
            t = datetime.datetime.fromisoformat(ts).replace(tzinfo=datetime.timezone.utc).timestamp()
            if t >= start: hits.append((t - start, "connected" if "connected" in line else "BGS-timeout"))
    print(f"run {i}: " + (", ".join(f"{k} at +{d:.3f} s" for d, k in hits) or "no EAGEP connect logged"), flush=True)
