#!/usr/bin/env bash
# Full mtld3d gates on the committed tip of the merge worktree, in the provisioned environment.
# Usage: pe_gates.sh <logdir>
set -u
W=/Volumes/ExT2/GameHub/work/mtld3d-merge
ENV=/Volumes/ExT2/GameHub/toolchains/mt-env
L=$1
mkdir -p "$L"
SUM=$L/summary.txt
: > "$SUM"
run() { local name=$1; shift; local s=$(date +%s); (cd "$W" && "$ENV" "$@") > "$L/$name.log" 2>&1; echo "$name exit=$? secs=$(( $(date +%s)-s )) cmd=[$*]" >> "$SUM"; }

{
  echo "head=$(git -C "$W" rev-parse HEAD) tree=$(git -C "$W" rev-parse HEAD^{tree}) dirty=$(git -C "$W" status --porcelain --untracked-files=no | wc -l | tr -d ' ')"
  "$ENV" bash -c 'echo WINE_SDK=$WINE_SDK; command -v rustc cargo cp; rustc +$RUST_STABLE -vV; cargo +$RUST_NIGHTLY fmt --version; cargo +$RUST_STABLE clippy -V; cargo-nextest nextest --version | head -1; xwin --version; "$WINE_SDK/bin/wine" --version; ls -l "$(command -v lld-link)"'
} > "$L/versions.txt" 2>&1

run check make check ISOLATED=1
run test make test ISOLATED=1 FAIL_FAST=0
run conformance make conformance ISOLATED=1
echo DONE >> "$SUM"
