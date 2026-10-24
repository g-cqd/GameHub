#!/bin/bash
# s2-rollback.sh: undo S2. Stops EA (ea-stop.sh), moves the three games back into EA Games/BF4,
# restores the hives, the EA ini and ProgramData/EA Desktop from LAST_BACKUP. Nothing is deleted:
# the files it replaces are moved to <backup>/rollback-moved-aside-<ts>/.
# usage: s2-rollback.sh [--dry-run|--apply]      (default --dry-run)
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
STAGE=S2R
IS_ROLLBACK=1
parse_mode "$@"
no_extra_args
install_trap

LIB="$G/EA Games"
BF4DIR="$LIB/BF4"
GAMES=("Battlefield 4" "Crysis 3" "F1 24")
baseline() {
  case "$1" in
    "Battlefield 4") echo "${EA_BASELINE_BF4:-764 66018133291}" ;;
    "Crysis 3") echo "${EA_BASELINE_CRYSIS3:-519 11371404328}" ;;
    "F1 24") echo "${EA_BASELINE_F124:-29496 70602312844}" ;;
  esac
}

log "S2 rollback, mode=$([ "$APPLY" = 1 ] && echo APPLY || echo dry-run)"
stop_ea || { log "ROLLBACK INCOMPLETE: EA could not be stopped; nothing was changed"; exit 1; }
B=""
if last_backup; then
  backup_verify "$B" backup || pf_fail "backup $B fails its own SHA256SUMS"
else
  pf_fail "LAST_BACKUP missing or incomplete ($LAST_BACKUP_FILE)"
fi
if [ "$APPLY" = 1 ] && prefix_wine_running; then pf_fail "prefix still in use: $PREFIX_RUN_REASON"; fi

TODO=()
for g in "${GAMES[@]}"; do
  new="$LIB/$g"
  old="$BF4DIR/$g"
  if [ -d "$new" ] && [ ! -e "$old" ]; then
    TODO+=("$g")
    same_volume "$new" "$LIB" || pf_fail "$new is on another volume"
  elif [ ! -e "$new" ] && [ -d "$old" ]; then
    log "$g is already back in BF4/, nothing to move"
  else
    pf_fail "unexpected state for $g: new=$([ -e "$new" ] && echo present || echo absent) old=$([ -e "$old" ] && echo present || echo absent)"
  fi
done
pf_end

TS=$(date -u +%Y%m%dT%H%M%SZ)
ASIDE="${B:-<LAST_BACKUP>}/rollback-moved-aside-$TS"
for g in ${TODO[@]+"${TODO[@]}"}; do
  read -r f b <<<"$(baseline "$g")"
  rb_step "mv -n '$LIB/$g' '$BF4DIR/$g' (mkdir BF4 if missing)" move_back_game "$g" "$LIB/$g" "$BF4DIR/$g" "$f" "$b"
done
# shellcheck disable=SC2329  # called through act
do_restore() { restore_state "$B/Prefix" "$ASIDE" 1; }
rb_step "restore hives, EA ini and ProgramData/EA Desktop from ${B:-<LAST_BACKUP>} (current ones go to $ASIDE)" do_restore
rollback_finish "$ASIDE"
exit "$DRY_RC"
