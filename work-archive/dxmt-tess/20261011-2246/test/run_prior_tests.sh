#!/bin/bash
# Runs the regression tests of the two previous DXMT packages (buffer RTV, staging
# rename) in this package's throwaway prefix against RUNTIME.
# usage: run_prior_tests.sh RUNTIME OUTDIR
RT=$1; OUT=$2
mkdir -p "$OUT"
export WINEPREFIX=/Volumes/ExT2/GameHub/work/dxmt-tess/prefix-test WINEDEBUG=-all
export WINE_COMPATDB="$(printf "v=3\nname=tesstest-0;exe=*;dxgi=dxmt")"
RTV=/Volumes/ExT2/GameHub/work/dxmt-rtv/20261011-1515/test
STG=/Volumes/ExT2/GameHub/work/dxmt-staging/20261011-1831/test
for a in i686 x86_64; do
  timeout 300 "$RT/bin/wine" $RTV/rtv_buffer_test-$a.exe > "$OUT/rtv-$a.log" 2>&1; echo "rtv_buffer_test $a exit=$?"
  timeout 300 "$RT/bin/wine" $STG/staging_rename_test-$a.exe > "$OUT/staging-$a.log" 2>&1; echo "staging_rename_test $a exit=$?"
done
"$RT/bin/wineserver" -w
