#!/bin/bash
# Repeats the failed-pipeline test to measure how often a valid pipeline that compiles
# while the Metal compiler service is crashing fails too.
# usage: flake_matrix.sh RUNS RUNTIME_NAME... (runtime-fix runtime-retry ...)
W=/Volumes/ExT2/GameHub/work/dxmt-tess
RUNS=$1; shift
mkdir -p $W/test/flake
for rt in "$@"; do
  for a in x86_64 i686; do
    for i in $(seq 1 "$RUNS"); do
      L=$W/test/flake/$rt-$a-$i.log
      TEST_TIMEOUT=150 $W/test/run_test.sh $W/$rt $a $L all 2000
      echo "$rt $a run$i: failedPSO=$(grep -c 'Failed to create mesh PSO' $L) retries=$(grep -c 'retrying pipeline creation' $L) $(grep -E 'RESULT|HANG' $L | tr '\n' ' ')"
    done
  done
done
