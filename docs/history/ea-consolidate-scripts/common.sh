#!/bin/bash
# shellcheck disable=SC2034  # shared globals, used by the sourcing scripts
# common.sh: sourced by every ea-consolidate script. No side effects on source.
# Conventions: STAGE (set by the script) names the log tag; APPLY=0 is the default dry run.
# Test-only variables (refused unless EA_TEST_MODE=1): EA_G_OVERRIDE (scratch GameHub root; everything
# below derives from it), EA_PREFIX_OVERRIDE, EA_RT_OVERRIDE, EA_LOG, EA_LAST_BACKUP_OVERRIDE, EA_PYTHON,
# EA_NFS_HASH_FILE, EA_STOP_WAIT_SECS, EA_STOP_TASKKILL_SECS, EA_STAGE, EA_BASELINE_<name> ("FILES BYTES").
# (EA_VERIFY_MAX only limits how many lines ea-verify.sh prints and is allowed.)

# Fail closed: a stray test variable in the caller's environment must never redirect a real run.
if [ "${EA_TEST_MODE:-}" != 1 ]; then
  _ea_bad=$(compgen -e | grep -E '^EA_(G_OVERRIDE|PREFIX_OVERRIDE|RT_OVERRIDE|LOG|LAST_BACKUP_OVERRIDE|PYTHON|NFS_HASH_FILE|STOP_WAIT_SECS|STOP_TASKKILL_SECS|STAGE|BASELINE_.*)$' | tr '\n' ' ' || true)
  if [ -n "$_ea_bad" ]; then
    echo "REFUSED: test-only variable(s) set without EA_TEST_MODE=1: $_ea_bad" >&2
    exit 2
  fi
  unset _ea_bad
else
  # test mode must name its own log and never the real one; export it so python helpers inherit it
  case "${EA_LOG:-}" in
    "" | /Volumes/ExT2/GameHub/docs/ea-library-consolidation-*.log)
      echo "REFUSED: EA_TEST_MODE=1 requires EA_LOG to point at a scratch log, not the real one" >&2
      exit 2 ;;
  esac
  export EA_LOG
fi

G=${EA_G_OVERRIDE:-/Volumes/ExT2/GameHub}
P=${EA_PREFIX_OVERRIDE:-$G/Prefix}
RT=${EA_RT_OVERRIDE:-$G/Runtimes/hub-0-winemacfs-dxmtrtv}
EA_SCRIPTS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
EA_LOG=${EA_LOG:-$G/docs/ea-library-consolidation-20261011.log}
LAST_BACKUP_FILE=${EA_LAST_BACKUP_OVERRIDE:-$EA_SCRIPTS/LAST_BACKUP}
BACKUPS_DIR=$G/Backups
WORK=$HOME/.agent-harness/bin/work
PY=${EA_PYTHON:-python3}
EA_USER_DIR="$P/drive_c/users/crossover"
EA_INI_DIR="$EA_USER_DIR/AppData/Local/Electronic Arts/EA Desktop"
EAINI="$EA_INI_DIR/user_5453960179173819204.ini"   # the known name; regrewrite.py globs user_*.ini and rewrites every match
WINE_HOME="/Users/gc/Library/Application Support/BF3Mac/RuntimeHome/Player"
export PYTHONDONTWRITEBYTECODE=1
STAGE=${STAGE:-S?}
APPLY=0
ARGS=()
PF_FAILS=0
DRY_RC=0
PREFIX_RUN_REASON=""

ts_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# log TEXT...: "[ISO8601] [Sx] text" appended to $EA_LOG with --apply; with --dry-run it is
# only printed (prefixed DRY-RUN) so a dry run never writes outside the script directory.
log() {
  local line
  line="[$(ts_iso)] [$STAGE] $*"
  if [ "$APPLY" = 1 ]; then
    printf '%s\n' "$line" >>"$EA_LOG"
    printf '%s\n' "$line"
  else
    printf '[DRY-RUN] %s\n' "$line"
  fi
}

# install_trap: log any unexpected command failure (set -e abort) with its line number.
IS_ROLLBACK=0
ea_err() {
  log "ABORTED: command failed at line $2 (rc=$1); state is as logged above, nothing is rolled back automatically"
  if [ "$IS_ROLLBACK" = 1 ]; then log "ROLLBACK INCOMPLETE: aborted by an unexpected failure (see above)"; fi
}
install_trap() { set -E; trap 'ea_err $? $LINENO' ERR; }

# refuse TEXT...: log the refusal and stop with status 2.
refuse() {
  log "REFUSED: $*"
  if [ "$IS_ROLLBACK" = 1 ]; then log "ROLLBACK INCOMPLETE: refused before any change was made"; fi
  exit 2
}

# pf_fail TEXT...: a failed precondition. Apply: refuse at once. Dry run: report and go on,
# the script then exits 2 through pf_end.
pf_fail() {
  if [ "$APPLY" = 1 ]; then refuse "$*"; fi
  PF_FAILS=$((PF_FAILS + 1))
  log "PREFLIGHT WOULD REFUSE: $*"
}
pf_end() {
  if [ "$PF_FAILS" -gt 0 ]; then
    DRY_RC=2
    log "dry-run: $PF_FAILS preflight check(s) would refuse; --apply would stop (the plan below is what would run if they passed)"
    return 0
  fi
  log "preflight: all checks pass"
}

# parse_mode "$@": sets APPLY (default 0) and ARGS (the other arguments).
parse_mode() {
  local seen_apply=0 seen_dry=0 a
  APPLY=0
  ARGS=()
  for a in "$@"; do
    case "$a" in
      --apply) seen_apply=1 ;;
      --dry-run) seen_dry=1 ;;
      *) ARGS+=("$a") ;;
    esac
  done
  if [ "$seen_apply" = 1 ] && [ "$seen_dry" = 1 ]; then
    echo "error: --apply and --dry-run are mutually exclusive" >&2
    exit 64
  fi
  if [ "$seen_apply" = 1 ]; then APPLY=1; fi
  return 0
}

# no_extra_args: for scripts that take no arguments besides the mode.
no_extra_args() {
  if [ "${#ARGS[@]}" -gt 0 ]; then
    echo "error: unexpected argument(s): ${ARGS[*]}" >&2
    exit 64
  fi
}

# act DESCRIPTION CMD...: log, run (apply) or only announce (dry run).
act() {
  local desc=$1 rc=0
  shift
  if [ "$APPLY" != 1 ]; then log "WOULD: $desc"; return 0; fi
  log "DO: $desc"
  "$@" || rc=$?
  if [ "$rc" -ne 0 ]; then log "FAILED (rc=$rc): $desc"; return "$rc"; fi
  log "OK: $desc"
}

# prefix_wine_running: 0 if ANY process has WINEPREFIX equal to $P (or an alias of it), or if the
# wineserver lock of $P is held (fcntl F_GETLK via wineserver_probe.py, also a cwd inside the server dir);
# 1 otherwise. The lock is the real guard: Windows-image processes such as winedevice.exe show no env. Processes of other prefixes (for instance
# work/wine-gepperf-tools/prefix) never count. A failure to read the process table counts as
# "running" (fail closed), as does an unprobeable lock. Sets PREFIX_RUN_REASON.
prefix_wine_running() {
  local out rc=0 sockdir devino
  PREFIX_RUN_REASON=""
  out=$("$PY" "$EA_SCRIPTS/prefix_procs.py" "$P") || rc=$?
  case $rc in
    0) PREFIX_RUN_REASON="process(es) with WINEPREFIX=$P: $(printf '%s' "$out" | tr '\n\t' '; ')"; return 0 ;;
    1) ;;
    *) PREFIX_RUN_REASON="cannot read the process table (rc=$rc), assuming the prefix is in use"; return 0 ;;
  esac
  if [ -e "$P" ]; then
    devino=$(/usr/bin/stat -f '%d %i' "$P") || { PREFIX_RUN_REASON="cannot stat $P, assuming the prefix is in use"; return 0; }
    sockdir=/tmp/.wine-$(id -u)/server-$(printf '%x-%x' "${devino% *}" "${devino#* }")
    rc=0
    out=$("$PY" "$EA_SCRIPTS/wineserver_probe.py" "$sockdir") || rc=$?
    case $rc in
      0) ;;
      1) PREFIX_RUN_REASON="$out"; return 0 ;;
      *) PREFIX_RUN_REASON="wineserver lock of $sockdir cannot be probed (rc=$rc: $out), assuming the prefix is in use"; return 0 ;;
    esac
  fi
  return 1
}

same_volume() { [ "$(/usr/bin/stat -f %d "$1")" = "$(/usr/bin/stat -f %d "$2")" ]; }
# free_kb PATH: available 1K blocks of the volume holding PATH.
free_kb() { /bin/df -k "$1" | awk 'NR==2 {print $4}'; }

# treestat DIR: one "files=.. bytes=.. ..." line (python os.walk/lstat).
treestat() { "$PY" "$EA_SCRIPTS/treestat.py" "$1"; }
# stat_field LINE KEY
stat_field() { printf '%s\n' "$1" | tr ' ' '\n' | sed -n "s/^$2=//p"; }
# tree_matches DIR FILES BYTES: sets TREE_STATS; 0 when file count and bytes both equal.
tree_matches() {
  TREE_STATS=$(treestat "$1") || return 2
  [ "$(stat_field "$TREE_STATS" files)" = "$2" ] && [ "$(stat_field "$TREE_STATS" bytes)" = "$3" ]
}

# require_work: the work tool is needed for every bounded wait.
require_work() { [ -x "$WORK" ] || { log "REFUSED: $WORK is missing or not executable"; exit 2; }; }

# wait_pid PID SECONDS: 0 when PID exited, 124 on timeout (work wait, no sleep).
wait_pid() { "$WORK" wait --pid "$1" --timeout "$2" >/dev/null 2>&1; }

# WINE_ENV: command prefix that runs a command in the clean environment start-ea.sh uses, for the
# shared prefix only:  "${WINE_ENV[@]}" "$RT/bin/wineserver" -w
WINE_ENV=(/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin HOME="$WINE_HOME" WINEPREFIX="$P"
  WINEDEBUG=-all WINEMSYNC=1)

# ---- backups -------------------------------------------------------------------------
# last_backup: sets B from LAST_BACKUP; 1 when missing or not a directory.
last_backup() {
  B=""
  [ -f "$LAST_BACKUP_FILE" ] || return 1
  B=$(head -n 1 "$LAST_BACKUP_FILE")
  [ -n "$B" ] && [ -d "$B" ] && [ -f "$B/SHA256SUMS" ]
}

# backup_verify DIR MODE: shasum -c of DIR/SHA256SUMS run from DIR; MODE=both also runs it
# from the prefix's parent, whose layout the relative paths mirror (the originals).
backup_verify() {
  local d=$1 mode=${2:-backup}
  [ -f "$d/SHA256SUMS" ] || return 1
  (cd "$d" && /usr/bin/shasum -a 256 -c -q SHA256SUMS) || return 1
  if [ "$mode" = both ]; then
    # the relative paths (Prefix/...) mirror the originals' layout below the prefix's parent
    (cd "$(dirname "$P")" && /usr/bin/shasum -a 256 -c -q "$d/SHA256SUMS") || return 2
  fi
  return 0
}

# write_sums ROOT OUTFILE REL...: sha256 of every regular file below each REL (relative to ROOT).
write_sums() {
  local root=$1 out=$2 rel
  shift 2
  : >"$out" || return 1
  for rel in "$@"; do
    [ -d "$root/$rel" ] || { log "FAILED: write_sums: $root/$rel is not a directory"; return 1; }
    # pipefail inside the subshell: a failing find, sort or shasum (xargs exits 123) fails the whole step
    (set -o pipefail; cd "$root" && /usr/bin/find "$rel" -type f -print0 | LC_ALL=C /usr/bin/sort -z |
      /usr/bin/xargs -0 -n 64 /usr/bin/shasum -a 256) >>"$out" || { log "FAILED: write_sums for $rel"; return 1; }
  done
}

# run_bounded SECONDS DESCRIPTION CMD...: run CMD in the background and wait for it with
# `work wait --pid` (no sleep). On timeout the (own, child) process is terminated and 124 returned.
run_bounded() {
  local secs=$1 desc=$2 pid rc=0 outf
  shift 2
  outf=$(/usr/bin/mktemp /tmp/ea-bounded.XXXXXX)
  "$@" >"$outf" 2>&1 &
  pid=$!
  if wait_pid "$pid" "$secs"; then
    wait "$pid" || rc=$?
  else
    log "TIMEOUT after ${secs}s: $desc (terminating our own pid $pid)"
    /usr/bin/pkill -P "$pid" 2>/dev/null || true
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rc=124
  fi
  if [ -s "$outf" ]; then log "output of $desc: $(head -c 400 "$outf" | tr '\r\n' '  ')"; fi
  /bin/rm -f "$outf"
  return "$rc"
}

# ---- stop / restore helpers shared by the rollback scripts --------------------------------
APPDATA_REL=drive_c/users/crossover/AppData/Local

# stop_ea: run ea-stop.sh in the current mode; it must leave the prefix idle (or, in a dry run, only print).
stop_ea() {
  local m=--dry-run
  if [ "$APPLY" = 1 ]; then m=--apply; fi
  bash "$EA_SCRIPTS/ea-stop.sh" "$m"
}

sha_of() { /usr/bin/shasum -a 256 "$1" | awk '{print $1}'; }

# verify_tree_sums SRCROOT DSTROOT REL: every regular file below SRCROOT/REL must exist in DSTROOT/REL
# with the same sha256.
verify_tree_sums() {
  local sums rc=0
  sums=$(/usr/bin/mktemp /tmp/ea-sums.XXXXXX)
  if write_sums "$1" "$sums" "$3"; then
    (cd "$2" && /usr/bin/shasum -a 256 -c -q "$sums") || rc=$?
  else
    rc=1
  fi
  /bin/rm -f "$sums"
  return "$rc"
}

# restore_undo DST ASIDE MOVED: after a failed restore, best effort: park the partial copy next to the aside
# copy (".partial", nothing deleted) and put the original back where it was.
restore_undo() {
  if [ -e "$1" ]; then
    /bin/mkdir -p "$(dirname "$2")" && /bin/mv -n "$1" "$2.partial" && log "parked the partial restore as $2.partial"
  fi
  if [ "$3" = 1 ] && [ ! -e "$1" ] && /bin/mv -n "$2" "$1"; then log "put the original back: $1"; fi
  return 0
}

# move_aside DST ASIDE: rename DST to ASIDE (same volume, nothing deleted) and prove it worked.
move_aside() {
  /bin/mkdir -p "$(dirname "$2")" || { log "FAILED: cannot create $(dirname "$2")"; return 1; }
  /bin/mv -n "$1" "$2" || { log "FAILED: could not move $1 aside to $2"; return 1; }
  if [ -e "$1" ] || [ ! -e "$2" ]; then
    log "FAILED: move-aside of $1 to $2 did not take effect"
    return 1
  fi
  log "moved aside $1 -> $2"
}

# restore_file SRCROOT REL ASIDE: put SRCROOT/REL at $P/REL (cp -p), moving the current file to
# ASIDE/Prefix/REL first (nothing is deleted); verifies the sha256. Returns 1 on any failure.
restore_file() {
  local src=$1/$2 dst=$P/$2 aside=$3/Prefix/$2 moved=0
  [ -f "$src" ] || { log "FAILED: backup file missing: $src"; return 1; }
  if [ -e "$dst" ]; then
    move_aside "$dst" "$aside" || return 1
    moved=1
  fi
  if ! /bin/cp -p "$src" "$dst" || [ "$(sha_of "$src")" != "$(sha_of "$dst")" ]; then
    log "FAILED: copy or sha256 check of restored $dst (source $src)"
    restore_undo "$dst" "$aside" "$moved"
    return 1
  fi
  log "restored $2 (sha256 $(sha_of "$dst"))"
}

# restore_tree SRCROOT REL ASIDE: replace $P/REL by a clone of SRCROOT/REL; the current tree is moved
# to ASIDE/Prefix/REL (no deletion); every file is verified by sha256. Returns 1 on any failure.
restore_tree() {
  local src=$1/$2 dst=$P/$2 aside=$3/Prefix/$2 moved=0
  [ -d "$src" ] || { log "FAILED: backup tree missing: $src"; return 1; }
  if [ -e "$dst" ]; then
    move_aside "$dst" "$aside" || return 1
    moved=1
  fi
  if ! /bin/cp -c -pRP "$src" "$dst" || ! verify_tree_sums "$1" "$P" "$2"; then
    log "FAILED: copy or verification of restored tree $dst (source $src)"
    restore_undo "$dst" "$aside" "$moved"
    return 1
  fi
  log "restored tree $2 and verified every file"
}

# restore_state SRC_PREFIX_ROOT ASIDE WITH_INI: hives, optionally the EA ini file(s), and ProgramData/EA Desktop.
# Every part is attempted; the result is 1 if any part failed.
restore_state() {
  local src=$1 aside=$2 with_ini=$3 f ini rc=0
  for f in system.reg user.reg userdef.reg; do restore_file "$src" "$f" "$aside" || rc=1; done
  if [ "$with_ini" = 1 ]; then
    for ini in "$src/$APPDATA_REL/Electronic Arts/EA Desktop"/user_*.ini; do
      [ -f "$ini" ] || continue
      restore_file "$src" "${ini#"$src"/}" "$aside" || rc=1
    done
  fi
  restore_tree "$src" "drive_c/ProgramData/EA Desktop" "$aside" || rc=1
  return "$rc"
}

# move_back_game NAME FROM TO FILES BYTES: undo one game move (FROM currently holds it). A failed rename is an
# error; a tree that differs from the baseline afterwards is only a WARNING so the hive restore still runs.
move_back_game() {
  local g=$1 from=$2 to=$3
  /bin/mkdir -p "$(dirname "$to")" || { log "FAILED: cannot create $(dirname "$to")"; return 1; }
  /bin/mv -n "$from" "$to" || { log "FAILED: mv of $g back failed"; return 1; }
  if [ -e "$from" ] || [ ! -d "$to" ]; then
    log "FAILED: moving $g back: source still there or target missing"
    return 1
  fi
  if ! tree_matches "$to" "$4" "$5"; then
    log "WARNING: $g after moving back: ${TREE_STATS:-unreadable}, expected $4 files / $5 bytes (continuing; check by hand)"
    return 0
  fi
  log "$g moved back to $to ($TREE_STATS)"
}

# Rollback bookkeeping: rb_step runs one step, remembers a failure and goes on; rollback_finish reports.
RB_FAIL=0
rb_step() { act "$@" || RB_FAIL=1; return 0; }
rollback_finish() {
  if [ "$RB_FAIL" != 0 ]; then
    log "ROLLBACK INCOMPLETE: at least one step failed (see the FAILED lines above); replaced files are under ${1:-the aside directory}"
    exit 1
  fi
  if [ "$APPLY" = 1 ]; then log "ROLLBACK COMPLETE; replaced files are under ${1:-the aside directory}"; fi
}
