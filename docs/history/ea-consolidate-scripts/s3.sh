#!/bin/bash
# s3.sh (S3): remove the Need for Speed hard-link mirror under Relocated/NFS2015Mac after proving that every
# mirror file is a second link to the real file in EA Games/Need for Speed (no data is lost, no space freed).
# usage: s3.sh [--dry-run|--apply]      (default --dry-run)
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
STAGE=S3
parse_mode "$@"
no_extra_args
install_trap

M="$G/Relocated/NFS2015Mac/Data/Prefix/drive_c/Program Files/EA Games/Need for Speed"
R="$G/EA Games/Need for Speed"
HASHES=${EA_NFS_HASH_FILE:-$EA_SCRIPTS/nfs-real-sha256-before.txt}
read -r NFS_FILES NFS_BYTES <<<"${EA_BASELINE_NFS:-144 14639595955}"

log "S3 NFS mirror removal, mode=$([ "$APPLY" = 1 ] && echo APPLY || echo dry-run)"
[ -d "$M" ] || pf_fail "mirror missing: $M"
[ -d "$R" ] || pf_fail "real library folder missing: $R"
if [ "$PF_FAILS" -gt 0 ]; then pf_end; exit "$DRY_RC"; fi

args=(--mirror "$M" --real "$R" --hash-file "$HASHES" --files "$NFS_FILES" --bytes "$NFS_BYTES" --stage S3 --log "$EA_LOG")
if [ "$APPLY" = 1 ]; then args+=(--apply); fi
rc=0
"$PY" "$EA_SCRIPTS/nfs_mirror.py" "${args[@]}" || rc=$?
case $rc in
  0) ;;
  2) DRY_RC=2; if [ "$APPLY" = 1 ]; then exit 2; fi ;;
  *) log "FAILED: nfs_mirror.py rc=$rc (see the lines above; the real files are untouched by design, only mirror links may be gone)"; exit "$rc" ;;
esac
exit "$DRY_RC"
