#!/bin/bash
# s2.sh (S2): move Battlefield 4, Crysis 3 and F1 24 out of EA Games/BF4 into EA Games/, rewrite the
# registry/ini paths (rule BF4) and remove the now empty EA Games/BF4.
# usage: s2.sh [--dry-run|--apply]      (default --dry-run)
# Prerequisites: EA and its wineserver stopped (ea-stop.sh --apply), backup.sh --apply done.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
STAGE=S2
parse_mode "$@"
no_extra_args
install_trap

LIB="$G/EA Games"
BF4DIR="$LIB/BF4"
GAMES=("Battlefield 4" "Crysis 3" "F1 24")
MAX_FREE_DROP_KB=1048576     # 1 GiB
EXPECT=(--expect system.reg=113 --expect user.reg=2 --expect userdef.reg=0 --expect ini=1)

# S0 baselines "FILES BYTES" (regular files; os.walk + lstat)
baseline() {
  case "$1" in
    "Battlefield 4") echo "${EA_BASELINE_BF4:-764 66018133291}" ;;
    "Crysis 3") echo "${EA_BASELINE_CRYSIS3:-519 11371404328}" ;;
    "F1 24") echo "${EA_BASELINE_F124:-29496 70602312844}" ;;
    *) return 1 ;;
  esac
}

log "S2 move BF4/Crysis 3/F1 24, mode=$([ "$APPLY" = 1 ] && echo APPLY || echo dry-run)"

# ---- preflight ----
if prefix_wine_running; then pf_fail "prefix is in use: $PREFIX_RUN_REASON (run ea-stop.sh --apply first)"; fi
B=""
if last_backup; then
  rc=0
  backup_verify "$B" both || rc=$?
  case $rc in
    0) log "LAST_BACKUP $B verifies against the copy and the current originals" ;;
    1) pf_fail "backup $B fails its own SHA256SUMS" ;;
    *) pf_fail "current hives/ProgramData/EA AppData differ from backup $B (take a new backup with backup.sh)" ;;
  esac
else
  pf_fail "LAST_BACKUP missing or its directory/SHA256SUMS is gone ($LAST_BACKUP_FILE): run backup.sh --apply first"
fi
for g in "${GAMES[@]}"; do
  src=$BF4DIR/$g
  dst=$LIB/$g
  if [ ! -d "$src" ] || [ -L "$src" ]; then pf_fail "source missing: $src"; continue; fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then pf_fail "target already exists: $dst"; fi
  same_volume "$src" "$LIB" || pf_fail "$src and $LIB are on different volumes (mv would copy)"
  read -r want_files want_bytes <<<"$(baseline "$g")"
  if tree_matches "$src" "$want_files" "$want_bytes"; then
    log "source $g matches S0 baseline: $TREE_STATS"
  else
    pf_fail "source $g differs from S0 baseline ($want_files files / $want_bytes bytes): $TREE_STATS"
  fi
done
if [ -d "$BF4DIR" ]; then
  extras=$(/usr/bin/find "$BF4DIR" -mindepth 1 -maxdepth 1 ! -name .DS_Store ! -name 'Battlefield 4' ! -name 'Crysis 3' ! -name 'F1 24' | sed -n '1,5p')
  [ -z "$extras" ] || pf_fail "unexpected entries in $BF4DIR: $extras"
fi
rc=0
rr=$("$PY" "$EA_SCRIPTS/regrewrite.py" --rule BF4 --root "$P" --stage S2 "${EXPECT[@]}" 2>&1) || rc=$?
printf '%s\n' "$rr" | grep -E ' count |REFUSED|dry-run:' | sed 's/^/    /' || true
[ "$rc" -eq 0 ] || pf_fail "regrewrite.py --rule BF4 dry-run refuses (rc=$rc)"
FREE_BEFORE=$(free_kb "$G")
log "free space before: ${FREE_BEFORE} KiB"
pf_end

# ---- actions ----
# shellcheck disable=SC2329  # called through act
move_game() {
  local g=$1 want_files want_bytes
  read -r want_files want_bytes <<<"$(baseline "$g")"
  /bin/mv -n "$BF4DIR/$g" "$LIB/$g" || { log "FAILED: mv of $g"; return 1; }
  if [ -e "$BF4DIR/$g" ] || [ ! -d "$LIB/$g" ]; then
    log "FAILED: after mv, source still present or target missing for $g"
    return 1
  fi
  if ! tree_matches "$LIB/$g" "$want_files" "$want_bytes"; then
    log "FAILED: $g after the move: $TREE_STATS, expected $want_files files / $want_bytes bytes"
    return 1
  fi
  log "$g moved: $TREE_STATS"
}
for g in "${GAMES[@]}"; do
  act "mv -n '$BF4DIR/$g' '$LIB/$g' and verify against the S0 baseline" move_game "$g"
done
act "regrewrite.py --rule BF4 --apply (113 + 2 + 0 + ini 1)" \
  "$PY" "$EA_SCRIPTS/regrewrite.py" --rule BF4 --apply --root "$P" --stage S2 "${EXPECT[@]}"

# shellcheck disable=SC2329  # called through act
remove_bf4_dir() {
  local extra
  extra=$(/usr/bin/find "$BF4DIR" -mindepth 1 -maxdepth 1 ! -name .DS_Store) || { log "WARNING: cannot list $BF4DIR; left in place"; return 0; }
  if [ -n "$extra" ]; then
    log "WARNING: $BF4DIR still holds: $extra (left in place, not removed)"
    return 0
  fi
  if [ -e "$BF4DIR/.DS_Store" ]; then
    if [ ! -f "$BF4DIR/.DS_Store" ] || [ -L "$BF4DIR/.DS_Store" ]; then
      log "WARNING: $BF4DIR/.DS_Store is not a regular file; left in place"
      return 0
    fi
    /bin/rm -f -- "$BF4DIR/.DS_Store" || { log "WARNING: could not remove $BF4DIR/.DS_Store"; return 0; }
  fi
  if /bin/rmdir "$BF4DIR"; then
    log "removed $BF4DIR"
  else
    log "WARNING: rmdir $BF4DIR failed (Finder re-creating .DS_Store?); the games are moved and registered, remove it by hand later"
  fi
  return 0
}
act "remove $BF4DIR/.DS_Store and rmdir $BF4DIR (rmdir only)" remove_bf4_dir

if [ "$APPLY" = 1 ]; then
  FREE_AFTER=$(free_kb "$G")
  DROP=$((FREE_BEFORE - FREE_AFTER))
  log "free space: before ${FREE_BEFORE} KiB, after ${FREE_AFTER} KiB, delta ${DROP} KiB dropped (other jobs write to this volume)"
  if [ "$DROP" -gt "$MAX_FREE_DROP_KB" ]; then
    log "FAILED: free space dropped by more than 1 GiB; renames should cost nothing, investigate"
    exit 1
  fi
  log "S2 complete. Next: start EA (bin/start-ea.sh) from a recorded marker (ea-verify.sh mark), then ea-verify.sh check"
else
  log "dry-run: free space after the run would be compared with ${FREE_BEFORE} KiB (limit 1 GiB drop)"
fi
exit "$DRY_RC"
