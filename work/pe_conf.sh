#!/usr/bin/env bash
# HISTORICAL - references paths/branches that no longer exist
# (/Volumes/ExT2/GameHub/work/mtld3d-merge, mtld3d-up). Kept as a record only; do not run.
# Commit the two fixes, then diagnose the d3d9ex hang on upstream and on the tip,
# then run the whole conformance suite on the tip. Usage: pe_conf.sh <logdir>
set -u
W=/Volumes/ExT2/GameHub/work/mtld3d-merge
U=/Volumes/ExT2/GameHub/work/mtld3d-up
ENV=/Volumes/ExT2/GameHub/toolchains/mt-env
L=$1
mkdir -p "$L/raw-up" "$L/raw-tip" "$L/raw-tip-full"
SUM=$L/summary.txt
: > "$SUM"
run() { local name=$1 dir=$2; shift 2; local s=$(date +%s); (cd "$dir" && "$ENV" "$@") > "$L/$name.log" 2>&1; echo "$name exit=$? secs=$(( $(date +%s)-s ))" >> "$SUM"; }

git -C "$W" add windows/tests/tests/e2e/render_states.rs && git -C "$W" commit -q -F /Volumes/ExT2/GameHub/work/lint-msg.txt
git -C "$W" add windows/d3d9/src/surface.rs windows/d3d9/src/swapchain.rs && git -C "$W" commit -q -F /Volumes/ExT2/GameHub/work/refcount-msg.txt
echo "tip=$(git -C "$W" rev-parse HEAD) dirty=$(git -C "$W" status --porcelain --untracked-files=no | wc -l | tr -d ' ')" >> "$SUM"
git -C "$W" log -4 --format='%h %s' >> "$SUM"

[ -d "$U" ] || git -C /Users/gc/Developer/mtld3d worktree add --detach "$U" f7cb3f2 >> "$SUM" 2>&1
echo "upstream=$(git -C "$U" rev-parse HEAD)" >> "$SUM"

run d3d9ex-upstream "$U" make conformance-isolate ISOLATED=1 ONLY=d3d9ex ARCH=i686 REPEAT=1 MTLD3D_CONFORMANCE_RAW_DIR="$L/raw-up"
run d3d9ex-tip "$W" make conformance-isolate ISOLATED=1 ONLY=d3d9ex ARCH=i686 REPEAT=1 MTLD3D_CONFORMANCE_RAW_DIR="$L/raw-tip"
run conformance-tip "$W" make -k conformance ISOLATED=1 MTLD3D_CONFORMANCE_RAW_DIR="$L/raw-tip-full"
echo DONE >> "$SUM"
