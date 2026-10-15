#!/usr/bin/env python3
"""Print gaps > THRESH ms between consecutive +timestamp trace lines (with surrounding lines)."""
import re, sys
path = sys.argv[1]; thresh = float(sys.argv[2]) if len(sys.argv) > 2 else 40
prev = None; prevline = ""
for line in open(path, errors="replace"):
    m = re.match(r"(\d+\.\d+):([0-9a-f]{4}):", line)
    if not m or "ThreadIdealProcessor" in line: continue
    t = float(m.group(1))
    if prev is not None and (t - prev) * 1000 > thresh:
        print(f"--- gap {(t-prev)*1000:.0f} ms\n  < {prevline.strip()[:230]}\n  > {line.strip()[:230]}")
    prev, prevline = t, line
