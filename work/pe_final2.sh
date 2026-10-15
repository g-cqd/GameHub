#!/usr/bin/env bash
# HISTORICAL - references paths/branches that no longer exist
# (/Volumes/ExT2/GameHub/work/mtld3d-merge, mtld3d-up). Kept as a record only; do not run.
# Commit the comment fix, then `make check`, `make test` and conformance on the final tip.
# Usage: pe_final2.sh <logdir>
set -u
W=/Volumes/ExT2/GameHub/work/mtld3d-merge
ENV=/Volumes/ExT2/GameHub/toolchains/mt-env
L=$1
mkdir -p "$L/raw-tip"
SUM=$L/summary.txt
: > "$SUM"
run() { local name=$1; shift; local s=$(date +%s); (cd "$W" && "$ENV" "$@") > "$L/$name.log" 2>&1; echo "$name exit=$? secs=$(( $(date +%s)-s ))" >> "$SUM"; }

python3 /Volumes/ExT2/GameHub/work/fix_citation.py >> "$SUM" 2>&1
git -C "$W" add windows/d3d9/src/surface.rs && git -C "$W" commit -q -F /Volumes/ExT2/GameHub/work/citation-msg.txt
echo "tip=$(git -C "$W" rev-parse HEAD) tree=$(git -C "$W" rev-parse HEAD^{tree}) dirty=$(git -C "$W" status --porcelain --untracked-files=no | wc -l | tr -d ' ')" >> "$SUM"
run check make check ISOLATED=1
run test make test ISOLATED=1 FAIL_FAST=0
run conformance make -k conformance ISOLATED=1 MTLD3D_CONFORMANCE_RAW_DIR="$L/raw-tip"
echo "tip-after=$(git -C "$W" rev-parse HEAD) dirty=$(git -C "$W" status --porcelain --untracked-files=no | wc -l | tr -d ' ')" >> "$SUM"
echo DONE >> "$SUM"
# Device-subtest repeats, tip and upstream alternating, to tell a flaky environment hang from a regression.
U=/Volumes/ExT2/GameHub/work/mtld3d-up
runu() { local name=$1; shift; local s=$(date +%s); (cd "$U" && "$ENV" "$@") > "$L/$name.log" 2>&1; echo "$name exit=$? secs=$(( $(date +%s)-s ))" >> "$SUM"; }
ioreg -n Root -d1 | grep -iE "CGSSessionScreenIsLocked|IOConsoleLocked" >> "$SUM" 2>&1
for arch in i686 x86_64; do
  for n in 1 2; do
    run "rep-tip-device-$arch-$n" make conformance-isolate ISOLATED=1 ONLY=device ARCH=$arch REPEAT=1 MTLD3D_CONFORMANCE_RAW_DIR="$L/rep-tip-$arch-$n"
    runu "rep-up-device-$arch-$n" make conformance-isolate ISOLATED=1 ONLY=device ARCH=$arch REPEAT=1 MTLD3D_CONFORMANCE_RAW_DIR="$L/rep-up-$arch-$n"
  done
done
echo DONE2 >> "$SUM"
