#!/usr/bin/env bash
# HISTORICAL - references paths/branches that no longer exist
# (/Volumes/ExT2/GameHub/work/mtld3d-merge, mtld3d-up). Kept as a record only; do not run.
# Commit the use-after-free fix, then the full gate set on the final tip, plus an
# upstream x86_64 d3d9ex control run. Usage: pe_final.sh <logdir>
set -u
W=/Volumes/ExT2/GameHub/work/mtld3d-merge
U=/Volumes/ExT2/GameHub/work/mtld3d-up
ENV=/Volumes/ExT2/GameHub/toolchains/mt-env
L=$1
mkdir -p "$L/raw-tip" "$L/raw-up"
SUM=$L/summary.txt
: > "$SUM"
run() { local name=$1 dir=$2; shift 2; local s=$(date +%s); (cd "$dir" && "$ENV" "$@") > "$L/$name.log" 2>&1; echo "$name exit=$? secs=$(( $(date +%s)-s ))" >> "$SUM"; }

git -C "$W" add windows/d3d9/src/surface.rs windows/d3d9/src/swapchain.rs windows/d3d9/src/com_ref.rs && git -C "$W" commit -q -F /Volumes/ExT2/GameHub/work/uaf-msg.txt
echo "tip=$(git -C "$W" rev-parse HEAD) tree=$(git -C "$W" rev-parse HEAD^{tree}) dirty=$(git -C "$W" status --porcelain --untracked-files=no | wc -l | tr -d ' ')" >> "$SUM"
git -C "$W" log -5 --format='%h %s' >> "$SUM"

for leg in fmt-check clippy-pe-i686 clippy-pe-x86_64 clippy-native clippy-perf audit test-isolation test-e2e-discovery test-unit-perf doc; do
  run "check-$leg" "$W" make "$leg" ISOLATED=1
done
run check-whole "$W" make check ISOLATED=1
run test "$W" make test ISOLATED=1 FAIL_FAST=0
run conformance "$W" make -k conformance ISOLATED=1 MTLD3D_CONFORMANCE_RAW_DIR="$L/raw-tip"
run d3d9ex-x86_64-upstream "$U" make conformance-isolate ISOLATED=1 ONLY=d3d9ex ARCH=x86_64 REPEAT=1 MTLD3D_CONFORMANCE_RAW_DIR="$L/raw-up"
echo "tip-after=$(git -C "$W" rev-parse HEAD) dirty=$(git -C "$W" status --porcelain --untracked-files=no | wc -l | tr -d ' ')" >> "$SUM"
echo DONE >> "$SUM"
