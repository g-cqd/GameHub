#!/bin/bash
# usage: run_test.sh RUNTIME ARCH(i686|x86_64) LOG [args...]
RT=$1; A=$2; LOG=$3; shift 3
export WINEPREFIX=/Volumes/ExT2/GameHub/work/dxmt-staging/prefix-test WINEDEBUG=-all
export WINE_COMPATDB="$(printf "v=3\nname=stgtest-0;exe=*;dxgi=dxmt")"
exec "$RT/bin/wine" /Volumes/ExT2/GameHub/work/dxmt-staging/test/staging_rename_test-$A.exe "$@" > "$LOG" 2>&1
