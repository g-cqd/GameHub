#!/usr/bin/env bash
# Promote the verified tip to development (fast-forward only), push it normally,
# then build the release bundle in the worktree's own target dir (scratch, no runtime touched).
# Usage: promote.sh <logdir>
set -u
TIP=0ab58d420496640ce41a8ee01df248148756953d
OLD=7d108a4a7bf983cb0f993ffae2aa39ca159f2c6f
R=/Users/gc/Developer/mtld3d
W=/Volumes/ExT2/GameHub/work/mtld3d-merge
ENV=/Volumes/ExT2/GameHub/toolchains/mt-env
L=$1; mkdir -p "$L"; SUM=$L/summary.txt; : > "$SUM"
say() { echo "$*" >> "$SUM"; }
die() { say "ABORT: $*"; echo DONE >> "$SUM"; exit 1; }

[ "$(git -C "$W" rev-parse HEAD)" = "$TIP" ] || die "worktree HEAD is not $TIP"
[ -z "$(git -C "$R" status --porcelain --untracked-files=no)" ] || die "main checkout has local changes"
[ "$(git -C "$R" symbolic-ref --short HEAD)" = development ] || die "main checkout is not on development"
git -C "$R" fetch origin >> "$L/git.log" 2>&1 || die "fetch origin failed"
say "origin/development before: $(git -C "$R" rev-parse origin/development)"
[ "$(git -C "$R" rev-parse origin/development)" = "$OLD" ] || die "origin/development moved away from $OLD; not pushing"
[ "$(git -C "$R" rev-parse development)" = "$OLD" ] || die "local development is not $OLD"
git -C "$R" merge-base --is-ancestor "$OLD" "$TIP" || die "tip does not descend from $OLD"
git -C "$R" merge --ff-only "$TIP" >> "$L/git.log" 2>&1 || die "ff-only merge failed"
say "development now: $(git -C "$R" rev-parse development)"
git -C "$R" push origin development >> "$L/git.log" 2>&1 || die "push failed (see git.log)"
git -C "$R" fetch origin >> "$L/git.log" 2>&1
say "origin/development after: $(git -C "$R" rev-parse origin/development)"

# The candidate tag kept the commit reachable until development held it. Left in
# place, `git describe` would stamp `candidate/...` into BUILD_ID instead of the
# v0.12.0-based identity every other checkout of this commit gets.
git -C "$R" tag -d candidate/mtld3d-20261010 >> "$L/git.log" 2>&1 && say "deleted local tag candidate/mtld3d-20261010 (was $(grep -o "was [0-9a-f]*" "$L/git.log" | tail -1))"
say "describe: $(git -C "$W" describe --tags --always)"

s=$(date +%s); (cd "$W" && "$ENV" make bundle) > "$L/bundle.log" 2>&1; say "bundle exit=$? secs=$(( $(date +%s)-s ))"
T=$W/windows/target
for f in "$T/mtld3d.tar.xz" "$T/mtld3d-debug.tar.xz"; do [ -f "$f" ] && say "$(shasum -a 256 "$f") $(stat -f %z "$f") bytes"; done
if [ -d "$T/bundle" ]; then
  (cd "$T/bundle" && find . -type f \( -name '*.dll' -o -name '*.so' \) -exec shasum -a 256 {} \;) >> "$SUM"
  for f in "$T/bundle/wine/i386-windows/d3d9.dll" "$T/bundle/wine/x86_64-windows/d3d9.dll"; do
    say "stamp $(basename "$(dirname "$f")"): $(LC_ALL=C grep -a -o -E "v0\.12\.0-[0-9]+-g[0-9a-f]+" "$f" | head -1)"
  done
fi
cat "$T/bundle-debug/BUILD" >> "$SUM" 2>/dev/null
(cd /Volumes/ExT2/GameHub/work/mtld3d-up && "$ENV" make clean-isolated) >> "$L/clean-up.log" 2>&1; say "upstream clean-isolated exit=$?"
git -C "$R" worktree remove --force /Volumes/ExT2/GameHub/work/mtld3d-up >> "$L/git.log" 2>&1 && say "removed upstream control worktree"
(cd "$W" && "$ENV" make clean-isolated) >> "$L/clean-merge.log" 2>&1; say "merge worktree clean-isolated exit=$?"
git -C "$R" worktree list >> "$SUM"
echo DONE >> "$SUM"
