#!/bin/bash
# s4-rollback.sh: undo S4. Stops EA (ea-stop.sh), moves Battlefield 3 back into the prefix and restores the three
# hives and ProgramData/EA Desktop from <LAST_BACKUP>/pre-s4. Nothing is deleted: replaced files go to
# <LAST_BACKUP>/pre-s4/rollback-moved-aside-<ts>/.
# usage: s4-rollback.sh [--dry-run|--apply]      (default --dry-run)
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
STAGE=S4R
IS_ROLLBACK=1
parse_mode "$@"
no_extra_args
install_trap

OLD="$P/drive_c/Program Files/EA Games/Battlefield 3"
NEW="$G/EA Games/Battlefield 3"
read -r BF3_FILES BF3_BYTES <<<"${EA_BASELINE_BF3:-1872 21382885726}"

log "S4 rollback, mode=$([ "$APPLY" = 1 ] && echo APPLY || echo dry-run)"
stop_ea || { log "ROLLBACK INCOMPLETE: EA could not be stopped; nothing was changed"; exit 1; }
B=""
if last_backup && [ -f "$B/pre-s4/SHA256SUMS" ]; then
  backup_verify "$B/pre-s4" backup || pf_fail "$B/pre-s4 fails its own SHA256SUMS"
else
  pf_fail "no pre-s4 backup under LAST_BACKUP ($LAST_BACKUP_FILE): S4 never got that far, or the backup is gone"
fi
if [ "$APPLY" = 1 ] && prefix_wine_running; then pf_fail "prefix still in use: $PREFIX_RUN_REASON"; fi
MOVE=0
if [ -d "$NEW" ] && [ ! -e "$OLD" ]; then
  MOVE=1
  same_volume "$NEW" "$G/EA Games" || pf_fail "volumes differ"
elif [ ! -e "$NEW" ] && [ -d "$OLD" ]; then
  log "Battlefield 3 is already back in the prefix, nothing to move"
else
  pf_fail "unexpected state: new=$([ -e "$NEW" ] && echo present || echo absent) old=$([ -e "$OLD" ] && echo present || echo absent)"
fi
pf_end

TS=$(date -u +%Y%m%dT%H%M%SZ)
ASIDE="${B:-<LAST_BACKUP>}/pre-s4/rollback-moved-aside-$TS"
if [ "$MOVE" = 1 ]; then
  rb_step "mv -n '$NEW' '$OLD' (mkdir -p of the parent if missing)" move_back_game "Battlefield 3" "$NEW" "$OLD" "$BF3_FILES" "$BF3_BYTES"
fi
# shellcheck disable=SC2329  # called through act
do_restore() { restore_state "$B/pre-s4/Prefix" "$ASIDE" 0; }
rb_step "restore hives and ProgramData/EA Desktop from ${B:-<LAST_BACKUP>}/pre-s4 (current ones go to $ASIDE)" do_restore
rollback_finish "$ASIDE"
exit "$DRY_RC"
