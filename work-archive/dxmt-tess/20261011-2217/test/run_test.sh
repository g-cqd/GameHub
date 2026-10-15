#!/bin/bash
# usage: run_test.sh RUNTIME ARCH(i686|x86_64) LOG [mode] [idle_ms]
# Runs the failed-pipeline regression test in the throwaway prefix of this package.
# A run that does not finish within TEST_TIMEOUT seconds (default 120) is a hang:
# the runner kills the prefix's wineserver and appends "HANG" and "exit=124".
RT=$1; A=$2; LOG=$3; shift 3
export WINEPREFIX=/Volumes/ExT2/GameHub/work/dxmt-tess/prefix-test WINEDEBUG=-all
export WINE_COMPATDB="$(printf "v=3\nname=tesstest-0;exe=*;dxgi=dxmt")"
export DXMT_SHADER_CACHE=0
timeout "${TEST_TIMEOUT:-120}" "$RT/bin/wine" /Volumes/ExT2/GameHub/work/dxmt-tess/test/failed_pipeline_test-$A.exe "$@" > "$LOG" 2>&1
rc=$?
if [ $rc -eq 124 ]; then
  "$RT/bin/wineserver" -k 2>/dev/null
  echo "HANG: killed after ${TEST_TIMEOUT:-120} s" >> "$LOG"
fi
echo "exit=$rc" >> "$LOG"
exit $rc
