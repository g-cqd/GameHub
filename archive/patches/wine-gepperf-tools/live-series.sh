#!/bin/bash
# Live comparison, manual EAGEP runs against the live prefix (allowed: <= 15/hour, each ends by
# itself after 16 s): "cur" = no sidecar + ROSETTA_DISABLE_AOT=1 (what a BGS child inherits today),
# "fix" = no sidecar, AOT on (what it gets with the ntdll fix). ABBA order, 240 s idle between runs.
T=/Volumes/ExT2/GameHub/work/wine-gepperf-tools
order=(cur fix fix cur cur fix fix cur cur fix fix cur cur fix fix cur)
i=0
for v in "${order[@]}"; do
  if [ $i -gt 0 ]; then ~/.agent-harness/bin/work wait --log /dev/null never-matches --timeout 240 >/dev/null 2>&1; fi
  if [ "$v" = cur ]; then GEP_X87= GEP_AOT=1 python3 $T/gep-live.py live-cur-$i; else GEP_X87= python3 $T/gep-live.py live-fix-$i; fi
  i=$((i+1))
done
