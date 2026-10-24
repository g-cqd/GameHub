#!/usr/bin/env python3
"""Interleaved R/N/C wall-time benchmark of `wine hostname` and `wine C:\\fontenum.exe min`.
R = runtime's original win32u.so (rt-base clone), N = new win32u.so with WINE_MAC_FONT_CACHE=0,
C = new win32u.so with the cache. Warm persistent wineserver on the throwaway prefix.
Usage: bench.py ROUNDS [variants] ; prints per-run lines and a summary."""
import os, subprocess, sys, time, statistics
W = "/Volumes/ExT2/GameHub/work/wine-fontperf/bin/w"
VAR = {"R": {"RT": "/Volumes/ExT2/GameHub/work/wine-fontperf/rt-base"},
       "N": {"EXTRA_ENV": "WINE_MAC_FONT_CACHE=0"},
       "C": {}}
CMDS = {"hostname": ["hostname"], "gdimin": ["C:\\fontenum.exe", "min"]}
rounds = int(sys.argv[1]); variants = sys.argv[2] if len(sys.argv) > 2 else "RNC"
res = {(v, c): [] for v in variants for c in CMDS}
def run(v, c):
    env = dict(os.environ); env.update(VAR[v])
    t = time.monotonic(); r = subprocess.run([W] + CMDS[c], env=env, cwd="/tmp", stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return time.monotonic() - t, r.returncode
for v in variants:            # warm-up, not recorded
    for c in CMDS: run(v, c)
for i in range(rounds):
    order = variants if i % 2 == 0 else variants[::-1]
    for c in CMDS:
        for v in order:
            dt, rc = run(v, c); res[(v, c)].append(dt)
            print(f"round {i} {c} {v} {dt*1000:.0f} ms rc={rc}", flush=True)
def p90(x): s = sorted(x); return s[min(len(s)-1, int(round(0.9*(len(s)-1))))]
print("\nload avg:", os.getloadavg())
for c in CMDS:
    for v in variants:
        x = res[(v, c)]
        print(f"{c:9s} {v}: n={len(x)} median={statistics.median(x)*1000:.0f} ms p90={p90(x)*1000:.0f} ms "
              f"min={min(x)*1000:.0f} max={max(x)*1000:.0f} IQR={(statistics.quantiles(x,n=4)[2]-statistics.quantiles(x,n=4)[0])*1000:.0f} ms")
