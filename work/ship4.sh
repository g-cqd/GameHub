#!/usr/bin/env bash
# Amend the unpushed d3d8 stamp commit, gate it, bundle it, then fast-forward
# development and push. Usage: ship2.sh <logdir>
set -u
OLD=0ab58d420496640ce41a8ee01df248148756953d
R=/Users/gc/Developer/mtld3d
W=/Volumes/ExT2/GameHub/work/mtld3d-merge
ENV=/Volumes/ExT2/GameHub/toolchains/mt-env
L=$1; mkdir -p "$L"; SUM=$L/summary.txt; : > "$SUM"
say() { echo "$*" >> "$SUM"; }
die() { say "ABORT: $*"; echo DONE >> "$SUM"; exit 1; }
run() { local name=$1; shift; local s=$(date +%s); (cd "$W" && "$ENV" "$@") > "$L/$name.log" 2>&1; local rc=$?; say "$name exit=$rc secs=$(( $(date +%s)-s ))"; return $rc; }

[ "$(git -C "$W" rev-parse HEAD^)" = "$OLD" ] || die "worktree HEAD^ is not $OLD"
[ "$(git -C "$R" rev-parse origin/development)" = "$OLD" ] || die "origin/development is not $OLD"
[ "$(git -C "$W" log -1 --format=%s)" = "Keep the build identity in d3d8.dll so the bundle can be assembled" ] || die "unexpected HEAD"
[ -z "$(git -C "$W" status --porcelain --untracked-files=no)" ] || die "worktree dirty"
TIP=$(git -C "$W" rev-parse HEAD)
say "tip=$TIP parent=$(git -C "$W" rev-parse HEAD^) describe=$(git -C "$W" describe --tags --always) dirty=$(git -C "$W" status --porcelain --untracked-files=no | wc -l | tr -d ' ')"
git -C "$W" show --stat --format='%h %s' HEAD >> "$SUM"

run precheck-build make windows-i686 PROD=1 || die "production i686 build failed"
LC_ALL=C grep -a -q -F "$(git -C "$W" describe --tags --always)" "$W/windows/target/i686-pc-windows-msvc/production/d3d8.dll" || die "d3d8.dll still carries no stamp"
say "precheck: production i686 d3d8.dll carries $(git -C "$W" describe --tags --always)"
run check make check ISOLATED=1 || die "make check failed"
run test make test ISOLATED=1 FAIL_FAST=0 || die "make test failed"
grep -E "Summary" "$L/test.log" | tail -4 >> "$SUM"
run bundle make bundle || die "make bundle failed"
T=$W/windows/target
for f in "$T/mtld3d.tar.xz" "$T/mtld3d-debug.tar.xz"; do say "$(shasum -a 256 "$f" | cut -d' ' -f1)  $(basename "$f")  $(stat -f %z "$f") bytes"; done
(cd "$T/bundle" && find . -type f \( -name '*.dll' -o -name '*.so' \) -exec shasum -a 256 {} \; | sort -k2) >> "$SUM"
say "BUILD file: $(cat "$T/bundle-debug/BUILD" 2>/dev/null)"
mkdir -p /Volumes/ExT2/GameHub/work/bundle-out && cp -c "$T/mtld3d.tar.xz" "$T/mtld3d-debug.tar.xz" /Volumes/ExT2/GameHub/work/bundle-out/ && say "copied archives to /Volumes/ExT2/GameHub/work/bundle-out"

[ -z "$(git -C "$R" status --porcelain --untracked-files=no)" ] || die "main checkout has local changes"
git -C "$R" fetch origin >> "$L/git.log" 2>&1 || die "fetch failed"
[ "$(git -C "$R" rev-parse origin/development)" = "$OLD" ] || die "origin/development moved away from $OLD"
git -C "$R" merge --ff-only "$TIP" >> "$L/git.log" 2>&1 || die "ff-only failed"
git -C "$R" push origin development >> "$L/git.log" 2>&1 || die "push failed"
git -C "$R" fetch origin >> "$L/git.log" 2>&1
say "development=$(git -C "$R" rev-parse development) origin/development=$(git -C "$R" rev-parse origin/development)"
(cd "$W" && "$ENV" make clean-isolated) >> "$L/clean.log" 2>&1; say "clean-isolated exit=$?"
echo DONE >> "$SUM"
