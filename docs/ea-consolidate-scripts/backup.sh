#!/bin/bash
# backup.sh (S1): APFS-clone backup of the registry hives, ProgramData and the EA/Origin
# AppData trees of the shared prefix, with SHA256SUMS verified against the copy and the originals.
# usage: backup.sh [--dry-run|--apply]      (default --dry-run)
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
STAGE=S1
parse_mode "$@"
no_extra_args
install_trap

APPDATA_REL=drive_c/users/crossover/AppData/Local
ITEMS_DIRS=("drive_c/ProgramData" "$APPDATA_REL/Electronic Arts")
if [ -d "$P/$APPDATA_REL/Origin" ]; then ITEMS_DIRS+=("$APPDATA_REL/Origin"); fi
ITEMS_FILES=(system.reg user.reg userdef.reg)

log "S1 backup, mode=$([ "$APPLY" = 1 ] && echo APPLY || echo dry-run), prefix=$P"
TS=$(date -u +%Y%m%dT%H%M%SZ)
B=$BACKUPS_DIR/ea-consolidate-$TS

# ---- preflight ----
if prefix_wine_running; then pf_fail "prefix is in use: $PREFIX_RUN_REASON (run ea-stop.sh first)"; fi
for f in "${ITEMS_FILES[@]}"; do
  [ -f "$P/$f" ] || pf_fail "missing $P/$f"
done
for d in "${ITEMS_DIRS[@]}"; do
  [ -d "$P/$d" ] && [ ! -L "$P/$d" ] || pf_fail "missing (or symlink) $P/$d"
done
[ -d "$BACKUPS_DIR" ] || pf_fail "backups directory $BACKUPS_DIR missing"
[ ! -e "$B" ] || pf_fail "$B already exists"
if [ -d "$BACKUPS_DIR" ] && ! same_volume "$P" "$BACKUPS_DIR"; then
  pf_fail "backup volume differs from the prefix volume (clones need the same APFS volume)"
fi
FREE_BEFORE=$(free_kb "$BACKUPS_DIR")
log "free space on backup volume: ${FREE_BEFORE} KiB (clones cost ~no space)"
for d in "${ITEMS_DIRS[@]}"; do
  if [ -d "$P/$d" ]; then
    log "source $d: $(du -sk "$P/$d" | awk '{print $1}') KiB, $(treestat "$P/$d")"
  fi
done
if [ -d "$P/drive_c/ProgramData/Package Cache" ]; then
  log "ProgramData/Package Cache alone: $(du -sk "$P/drive_c/ProgramData/Package Cache" | awk '{print $1}') KiB"
fi
pf_end

# ---- actions ----
log "backup directory will be $B"
act "mkdir -p backup tree" /bin/mkdir -p "$B/Prefix/$APPDATA_REL"
for f in "${ITEMS_FILES[@]}"; do
  act "clone $f" /bin/cp -c -p "$P/$f" "$B/Prefix/$f"
done
for d in "${ITEMS_DIRS[@]}"; do
  act "clone tree $d (symlinks copied as links)" /bin/cp -c -pRP "$P/$d" "$B/Prefix/$d"
done
if [ "$APPLY" != 1 ]; then
  log "would compare treestat of every source against its copy, write $B/SHA256SUMS, verify it from $B and from $(dirname "$P") (the originals), write $B/MANIFEST.txt and record $B in $LAST_BACKUP_FILE"
  exit "$DRY_RC"
fi

for d in "${ITEMS_DIRS[@]}"; do
  a=$(treestat "$P/$d")
  c=$(treestat "$B/Prefix/$d")
  if [ "$a" != "$c" ]; then
    log "FAILED: $d differs from its copy: original [$a] copy [$c]"
    exit 1
  fi
  log "copy of $d matches the original ($c)"
done
act "write SHA256SUMS" write_sums "$B" "$B/SHA256SUMS" Prefix
nsums=$(wc -l <"$B/SHA256SUMS" | tr -d ' ')
want=${#ITEMS_FILES[@]}
for d in "${ITEMS_DIRS[@]}"; do want=$((want + $(stat_field "$(treestat "$P/$d")" files))); done
if [ "$nsums" != "$want" ]; then
  log "FAILED: SHA256SUMS lists $nsums files but the sources hold $want regular files (hives + trees)"
  exit 1
fi
log "SHA256SUMS lists $nsums regular files (= hives + every regular file of the cloned trees)"
backup_verify "$B" both || { log "FAILED: SHA256SUMS verification (rc=$?; 1 = copy, 2 = originals)"; exit 1; }
log "SHA256SUMS verified from $B and from $(dirname "$P") (originals)"

{
  echo "ea-consolidate backup"
  echo "timestamp_utc: $TS"
  echo "prefix: $P"
  echo "free_kb_before: $FREE_BEFORE"
  echo "free_kb_after: $(free_kb "$BACKUPS_DIR")"
  echo "sha256sums_entries: $(wc -l <"$B/SHA256SUMS" | tr -d ' ')"
  for d in "${ITEMS_DIRS[@]}"; do echo "tree $d: $(treestat "$B/Prefix/$d")"; done
  for f in "${ITEMS_FILES[@]}"; do echo "file $f: $(/usr/bin/stat -f '%z bytes' "$B/Prefix/$f")"; done
  echo "du -sk (apparent, clones share blocks): $(du -sk "$B" | awk '{print $1}') KiB"
} >"$B/MANIFEST.txt"
log "wrote $B/MANIFEST.txt"

printf '%s\n' "$B" >"$LAST_BACKUP_FILE.tmp.$$"
/bin/mv -f "$LAST_BACKUP_FILE.tmp.$$" "$LAST_BACKUP_FILE"
log "recorded $B in $LAST_BACKUP_FILE"
printf '%s\n' "$B"
