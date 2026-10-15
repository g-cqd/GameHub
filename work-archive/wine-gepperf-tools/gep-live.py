#!/usr/bin/env python3
"""One manual EAGEP run against the LIVE prefix (allowed: max 15/hour, each ends by itself).

usage: gep-live.py LABEL [RT]
Runs gep-live.sh (EAGEP from RT, default the live runtime, against the live prefix; `timeout 16`),
then reports start -> BGS 'Client connected [EAGEP.exe]' and EAGEP's own markers, relative to the
moment the script starts wine.  Every run is appended to live-runs.log; the script refuses to run
when 15 runs happened in the last hour.
"""
import datetime, os, re, subprocess, sys, time

T = "/Volumes/ExT2/GameHub/work/wine-gepperf-tools"
LOGS = "/Volumes/ExT2/GameHub/Prefix/drive_c/ProgramData/EA Desktop/Logs/"
RUNLOG = T + "/live-runs.log"
MARK = [("A", "EAGEP.rcc.enc"), ("B", "cacertificates.rcc.enc"), ("C", "setNormalMode"),
        ("D", "[global-io-0]"), ("E", "[global-io-1]"), ("F", "[PlatformNetworkMonitor]"),
        ("G", "machash"), ("H", "Request Url=[https://statsigapi"), ("I", "ExperimentsStatus=loaded"),
        ("J", "Ipc Server listening"), ("K", "target: [localhost"), ("L", "connected to [localhost")]

def ts(line):
    m = re.search(r"\[(\d{4}-\d\d-\d\dT[\d:.]+)Z\]", line)
    return datetime.datetime.fromisoformat(m.group(1)).replace(tzinfo=datetime.timezone.utc).timestamp() if m else None

def main():
    label = sys.argv[1]
    rt = sys.argv[2] if len(sys.argv) > 2 else "/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv"
    now = time.time()
    recent = []
    if os.path.exists(RUNLOG):
        recent = [l for l in open(RUNLOG) if now - float(l.split()[0]) < 3600]
    if len(recent) >= 15:
        sys.exit(f"refusing: {len(recent)} live runs in the last hour")
    load = os.getloadavg()
    env = dict(os.environ, GEP_RT=rt)
    out = subprocess.run([T + "/gep-live.sh", f"/tmp/gepperf-live-{int(now)}.log"], capture_output=True, text=True, env=env).stdout
    start = float(re.search(r"start_epoch=([0-9.]+)", out).group(1))
    conn = None
    for line in open(LOGS + "EABackgroundService.log", errors="replace"):
        if "Client connected [EAGEP.exe]" in line:
            t = ts(line)
            if t and t >= start and conn is None: conn = t - start
    mk, pid = {}, None
    for line in open(LOGS + "EAGEPVerbose.log", errors="replace"):
        t = ts(line)
        if not t or t < start: continue
        m = re.search(r"PID:\s+(\d+)", line)
        if "EAGEP.rcc.enc" in line and pid is None: pid = m.group(1) if m else None
        if pid is None or not m or m.group(1) != pid: continue
        for k, s in MARK:
            if s in line and k not in mk: mk[k] = t - start
    segs = " ".join(f"{k}={mk[k]*1000:.0f}" for k, _ in MARK if k in mk)
    line = (f"{now:.0f} {label} rt={os.path.basename(rt)} connect={conn*1000 if conn else -1:.0f}ms "
            f"load={load[0]:.1f} | {segs}")
    with open(RUNLOG, "a") as f: f.write(line + "\n")
    print(line)

if __name__ == "__main__":
    main()
