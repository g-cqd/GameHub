#!/usr/bin/env bash
# HISTORICAL - references paths/branches that no longer exist
# (/Volumes/ExT2/GameHub/work/mtld3d-merge). Kept as a record only; do not run.
# Every leg of `make check` run on its own (so one red leg does not hide the next),
# then `make check` as a whole for the record. Usage: pe_check_legs.sh <logdir>
set -u
W=/Volumes/ExT2/GameHub/work/mtld3d-merge
ENV=/Volumes/ExT2/GameHub/toolchains/mt-env
L=$1
mkdir -p "$L"
SUM=$L/summary.txt
: > "$SUM"
echo "head=$(git -C "$W" rev-parse HEAD) tree=$(git -C "$W" rev-parse HEAD^{tree}) dirty=$(git -C "$W" status --porcelain --untracked-files=no | wc -l | tr -d ' ')" >> "$SUM"
run() { local name=$1; shift; local s=$(date +%s); (cd "$W" && "$ENV" "$@") > "$L/$name.log" 2>&1; echo "$name exit=$? secs=$(( $(date +%s)-s ))" >> "$SUM"; }
for leg in fmt-check clippy-pe-i686 clippy-pe-x86_64 clippy-native clippy-perf audit test-isolation test-e2e-discovery test-unit-perf doc; do
  run "$leg" make "$leg" ISOLATED=1
done
run check-whole make check ISOLATED=1
echo DONE >> "$SUM"
