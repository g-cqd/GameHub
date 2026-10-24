#!/bin/bash
# s4.sh (S4): move Battlefield 3 out of the prefix (drive_c/Program Files/EA Games) into EA Games/ and rewrite its
# registry paths (rule BF3). It does NOT stop EA: run ea-stop.sh --apply first.
# usage: s4.sh [--dry-run|--apply]      (default --dry-run)
# Because S2 changed the hives, S4 first clones them (and ProgramData/EA Desktop) to <LAST_BACKUP>/pre-s4/.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
STAGE=S4
parse_mode "$@"
no_extra_args
install_trap

SRC="$P/drive_c/Program Files/EA Games/Battlefield 3"
DST="$G/EA Games/Battlefield 3"
read -r BF3_FILES BF3_BYTES <<<"${EA_BASELINE_BF3:-1872 21382885726}"
EXPECT=(--expect system.reg=8 --expect user.reg=4 --expect userdef.reg=0)

log "S4 move Battlefield 3, mode=$([ "$APPLY" = 1 ] && echo APPLY || echo dry-run)"

# ---- preflight ----
if prefix_wine_running; then pf_fail "prefix is in use: $PREFIX_RUN_REASON (S4 does not stop EA; run ea-stop.sh --apply first)"; fi
B=""
if last_backup; then
  if backup_verify "$B" backup; then log "LAST_BACKUP $B verifies (S2 changed the live hives, so only the backup itself is checked)"
  else pf_fail "backup $B fails its own SHA256SUMS"; fi
  [ ! -e "$B/pre-s4" ] || pf_fail "$B/pre-s4 already exists (a previous S4 attempt?); move it aside deliberately"
else
  pf_fail "LAST_BACKUP missing or incomplete ($LAST_BACKUP_FILE): run backup.sh --apply first"
fi
if [ ! -d "$SRC" ] || [ -L "$SRC" ]; then pf_fail "source missing: $SRC"; fi
if [ -e "$DST" ] || [ -L "$DST" ]; then pf_fail "target already exists: $DST"; fi
if [ -d "$SRC" ] && [ -d "$G/EA Games" ]; then
  same_volume "$SRC" "$G/EA Games" || pf_fail "source and target volumes differ (mv would copy)"
fi
if [ -d "$SRC" ]; then
  if tree_matches "$SRC" "$BF3_FILES" "$BF3_BYTES"; then log "source matches S0 baseline: $TREE_STATS"
  else pf_fail "source differs from S0 baseline ($BF3_FILES files / $BF3_BYTES bytes): $TREE_STATS"; fi
fi
rc=0
rr=$("$PY" "$EA_SCRIPTS/regrewrite.py" --rule BF3 --root "$P" --stage S4 "${EXPECT[@]}" 2>&1) || rc=$?
printf '%s\n' "$rr" | grep -E ' count |REFUSED|dry-run:' | sed 's/^/    /' || true
[ "$rc" -eq 0 ] || pf_fail "regrewrite.py --rule BF3 dry-run refuses (rc=$rc)"
FREE_BEFORE=$(free_kb "$G")
log "free space before: ${FREE_BEFORE} KiB"
pf_end

# ---- actions ----
# shellcheck disable=SC2329  # called through act
pre_backup() {
  local pb="$B/pre-s4" f a c
  /bin/mkdir -p "$pb/Prefix/drive_c/ProgramData" || return 1
  for f in system.reg user.reg userdef.reg; do
    /bin/cp -c -p "$P/$f" "$pb/Prefix/$f" || { log "FAILED: cloning $f"; return 1; }
  done
  /bin/cp -c -pRP "$P/drive_c/ProgramData/EA Desktop" "$pb/Prefix/drive_c/ProgramData/EA Desktop" || { log "FAILED: cloning ProgramData/EA Desktop"; return 1; }
  a=$(treestat "$P/drive_c/ProgramData/EA Desktop") || return 1
  c=$(treestat "$pb/Prefix/drive_c/ProgramData/EA Desktop") || return 1
  if [ "$a" != "$c" ]; then
    log "FAILED: EA Desktop clone is incomplete: original [$a] copy [$c]"
    return 1
  fi
  write_sums "$pb" "$pb/SHA256SUMS" Prefix || return 1
  backup_verify "$pb" both || { log "FAILED: pre-s4 SHA256SUMS verification (rc=$?; 1 = copy, 2 = originals)"; return 1; }
  log "pre-s4 backup in $pb: $(wc -l <"$pb/SHA256SUMS" | tr -d ' ') files, EA Desktop tree identical ($c), SHA256SUMS verified from the copy and the originals"
}
# shellcheck disable=SC2329  # called through act
move_bf3() {
  /bin/mv -n "$SRC" "$DST" || { log "FAILED: mv of Battlefield 3"; return 1; }
  if [ -e "$SRC" ] || [ ! -d "$DST" ]; then log "FAILED: after mv the source is still there or the target is missing"; return 1; fi
  if ! tree_matches "$DST" "$BF3_FILES" "$BF3_BYTES"; then
    log "FAILED: Battlefield 3 after the move: $TREE_STATS, expected $BF3_FILES files / $BF3_BYTES bytes"
    return 1
  fi
  log "Battlefield 3 moved: $TREE_STATS"
}
# nothing is renamed unless the pre-backup is complete and verified
act "clone hives and ProgramData/EA Desktop to ${B:-<LAST_BACKUP>}/pre-s4 with SHA256SUMS" pre_backup ||
  { log "ABORT: pre-s4 backup incomplete; nothing was moved or rewritten"; exit 1; }
act "mv -n '$SRC' '$DST' and verify $BF3_FILES files / $BF3_BYTES bytes" move_bf3
act "regrewrite.py --rule BF3 --apply (system.reg 8, user.reg 4, userdef.reg 0)" \
  "$PY" "$EA_SCRIPTS/regrewrite.py" --rule BF3 --apply --root "$P" --stage S4 "${EXPECT[@]}"

if [ "$APPLY" = 1 ]; then
  left=$(/usr/bin/find "$P/drive_c/Program Files/EA Games" -mindepth 1 -maxdepth 1 | sed -n '1,3p')
  if [ -d "$P/drive_c/Program Files/EA Games" ]; then
    log "left in place (not deleted): $P/drive_c/Program Files/EA Games${left:+ (still holds: $left)}"
  fi
  FREE_AFTER=$(free_kb "$G")
  log "free space: before ${FREE_BEFORE} KiB, after ${FREE_AFTER} KiB, delta $((FREE_BEFORE - FREE_AFTER)) KiB dropped (other jobs write to this volume)"
  log "S4 complete. Next: ea-verify.sh mark, start EA, ea-verify.sh check"
else
  log "dry-run: the empty '$P/drive_c/Program Files/EA Games' would be left in place"
fi
exit "$DRY_RC"
