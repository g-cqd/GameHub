#!/usr/bin/env python3
"""Functional check of the ROSETTA_DISABLE_AOT restore: start launch32 (32-bit, under the sidecar)
-> EAGEP (64-bit) in the throwaway prefix and report ROSETTA_DISABLE_AOT / the stash variable in the
exec-time environment (ps -E) of the launcher and of EAGEP.  usage: envcheck.py RT"""
import re, subprocess, sys, threading, time
sys.path.insert(0, "/Volumes/ExT2/GameHub/work/wine-gepperf-tools"); import gep
rt = sys.argv[1]
threading.Thread(target=gep.listener, daemon=True).start()
p = subprocess.Popen([rt + "/bin/wine", r"C:\standin\launch32.exe"], env=gep.env_for(rt, {}), cwd="/tmp",
                     stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
seen = {}
t0 = time.time()
while time.time() - t0 < 15 and len(seen) < 2:
    out = subprocess.run(["ps", "-axww", "-o", "pid=,command="], capture_output=True, text=True).stdout
    for line in out.splitlines():
        pid, cmd = line.split(None, 1)
        for name in ("launch32.exe", "EAGEP.exe"):
            if cmd.startswith("C:\\") and name in cmd and name not in seen:
                env = subprocess.run(["ps", "-Eww", "-o", "command=", "-p", pid], capture_output=True, text=True).stdout
                if gep.PFX not in env: continue      # another prefix (the live one): not ours
                seen[name] = (re.findall(r"ROSETTA_DISABLE_AOT=\S*", env), re.findall(r"WINE_X87_SAVED\S*", env))
    time.sleep(0.05)
for k, v in seen.items(): print(f"{k}: {v[0] or ['ROSETTA_DISABLE_AOT unset']} stash={v[1] or 'none'}")
subprocess.run([rt + "/bin/wine", "taskkill", "/f", "/im", "EAGEP.exe"], env=gep.env_for(rt, {}),
               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
p.wait()
