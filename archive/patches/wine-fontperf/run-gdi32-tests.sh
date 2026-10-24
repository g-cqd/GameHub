#!/bin/bash
# Run every gdi32 test unit with variant $1 (R = runtime's original win32u.so, C = new with cache)
# and write per-unit logs to /Volumes/ExT2/GameHub/work/wine-fontperf/tests-$1/.
V=$1; OUT=/Volumes/ExT2/GameHub/work/wine-fontperf/tests-$V; mkdir -p $OUT
W=/Volumes/ExT2/GameHub/work/wine-fontperf/bin/w
[ "$V" = R ] && export RT=/Volumes/ExT2/GameHub/work/wine-fontperf/rt-base
cd /tmp
for t in bitmap brush clipping dc dib font gdiobj generated icm mapping metafile palette path pen; do
  WINETEST_PLATFORM=wine EXTRA_ENV="WINETEST_PLATFORM=wine" timeout 600 $W 'C:\gdi32_test.exe' $t > $OUT/$t.log 2>&1
  echo "$t rc=$? $(grep -E '^[0-9a-f]+:[a-z]+: [0-9]+ tests executed' $OUT/$t.log | tail -1)"
done
