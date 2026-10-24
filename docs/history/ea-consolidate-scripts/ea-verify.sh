#!/bin/bash
# ea-verify.sh: read EA Desktop's own logs after the library move and report, per game, the lines that show whether
# EA found the game in its new place or wants to download/repair it. Only bytes written after a marker are examined.
#
#   ea-verify.sh mark  [--apply] [--marker FILE]     record the size of every Logs/*.log (run BEFORE starting EA);
#                                                    default is a dry run that only prints the offsets
#   ea-verify.sh check [--since-marker FILE] [--stage Sx] [--apply]
#                                                    group the new log lines per game (read-only; --apply only adds
#                                                    a one-line summary to the shared log)
#   ea-verify.sh wait PATTERN TIMEOUT [--log NAME|PATH] [--since-marker FILE]
#                                                    wait (work wait --log, no sleep) until a NEW line of the log
#                                                    (default EADesktop.log) matches the ERE PATTERN; 0 matched, 124 timeout
#
# Log line format (CRLF, tab separated): "<seq>\t[<ISO ts>]\tPID: n\tTID: n\t<LEVEL>\t(<function>)\t<message>"
# e.g.  ...InstallStore::updateInfo)  IS update: set installInfo for softwareId=[ID] baseSlug=[slug] installedStatus=[Installed]
#       ...ContentInstallStateWatcher::watchPath)  ContentInstallStateWatcher::watchPath path [E:\EA Games\X\f.exe] for software [ID]
#       ...reconcileContentInstallInfo)  Located files for software [ID]. Setting state to Installed
#       ...getPathAndArgsLaunchParams)  [GAME] Got exePath=[E:\EA Games\X\f.exe] cmdArgs=[] from defaultLauncher.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
STAGE=VERIFY
parse_mode "$@"
install_trap

LOGDIR="$P/drive_c/ProgramData/EA Desktop/Logs"
MARKER=$EA_SCRIPTS/ea-verify.marker
MAXLINES=${EA_VERIFY_MAX:-40}
INFO_RE='watchPath|installedStatus|Located files|exePath'
# 'Locate' is an alarm for the "locate game" flow, but not for "Located files ... Installed"
ALARM_RE='Download|CalculatingBase|Repair|Verify|NotInstalled|needsRepair|Locate([^d]|$)'
OLD_PATH_RE='EA Games.BF4.|Program Files.EA Games.Battlefield 3'

GAME_NAMES=("Battlefield 4" "Crysis 3" "F1 24" "Need for Speed" "Battlefield 3")
game_alias() {
  case "$1" in
    "Battlefield 4") echo 'Battlefield 4|battlefield-4|Origin\.SFT\.50\.0000(019|105|133|175|193|194)' ;;
    "Crysis 3") echo 'Crysis 3|crysis-3|crysis3|6b22703e-6861-4356-b13e-a77b76be7d7a' ;;
    "F1 24") echo 'F1 24|f1-24|F1_24|Origin\.SFT\.50\.0001497' ;;
    "Need for Speed") echo 'Need for Speed|need-for-speed|NFS16|Origin\.SFT\.50\.0000347' ;;
    "Battlefield 3") echo 'Battlefield 3|battlefield-3|bf3\.exe|c9617fe2-f4dc-4a8f-b661-295f3924245f' ;;
  esac
}

usage() { sed -n '2,13p' "${BASH_SOURCE[0]}" >&2; exit 64; }
[ "${#ARGS[@]}" -ge 1 ] || usage
CMD=${ARGS[0]}
REST=("${ARGS[@]:1}")

marker_offset() { # FILE-BASENAME -> offset recorded in the marker, or empty
  [ -f "$MARKER" ] || return 0
  awk -F '\t' -v n="$1" '$2 == n {print $1}' "$MARKER" | tail -n 1
}

nlines() { wc -l <"$1" | tr -d ' '; }

list_logs() { # one path per line
  local f
  for f in "$LOGDIR"/*.log; do [ -f "$f" ] && printf '%s\n' "$f"; done
}

case "$CMD" in
  mark)
    while [ "${#REST[@]}" -gt 0 ]; do
      case "${REST[0]}" in --marker) MARKER=${REST[1]:?}; REST=("${REST[@]:2}") ;; *) usage ;; esac
    done
    lines=$(printf '# ea-verify marker %s\n' "$(ts_iso)"
      list_logs | while IFS= read -r f; do printf '%s\t%s\n' "$(/usr/bin/stat -f %z "$f")" "$(basename "$f")"; done)
    log "marker $MARKER records $(printf '%s\n' "$lines" | grep -vc '^#') log offsets"
    if [ "$APPLY" != 1 ]; then printf '%s\n' "$lines" | sed 's/^/    /'; exit 0; fi
    printf '%s\n' "$lines" >"$MARKER.tmp.$$"
    /bin/mv -f "$MARKER.tmp.$$" "$MARKER"
    log "wrote marker $MARKER"
    ;;

  check)
    LABEL=""
    while [ "${#REST[@]}" -gt 0 ]; do
      case "${REST[0]}" in
        --since-marker) MARKER=${REST[1]:?}; REST=("${REST[@]:2}") ;;
        --stage) LABEL=${REST[1]:?}; REST=("${REST[@]:2}") ;;
        *) usage ;;
      esac
    done
    [ -f "$MARKER" ] || { echo "no marker file $MARKER: run 'ea-verify.sh mark --apply' before starting EA" >&2; exit 2; }
    [ -d "$LOGDIR" ] || { echo "log directory missing: $LOGDIR" >&2; exit 2; }
    NEW=$(/usr/bin/mktemp /tmp/ea-verify.XXXXXX)
    trap '/bin/rm -f "$NEW"' EXIT
    total=0
    while IFS= read -r f; do
      b=$(basename "$f"); off=$(marker_offset "$b"); off=${off:-0}
      size=$(/usr/bin/stat -f %z "$f")
      if [ "$size" -lt "$off" ]; then echo "note: $b is smaller than at the mark (rotated/truncated), reading it from the start" >&2; off=0; fi
      if [ "$size" -gt "$off" ]; then
        /usr/bin/tail -c +$((off + 1)) "$f" | tr -d '\r' | awk -v b="$b" '{print b "\t" $0}' >>"$NEW"
        total=$((total + size - off))
      fi
    done < <(list_logs)
    echo "== ea-verify check${LABEL:+ ($LABEL)}: $total new bytes in $(nlines "$NEW") lines since marker $MARKER =="
    for g in "${GAME_NAMES[@]}"; do
      re=$(game_alias "$g")
      gl=$(/usr/bin/mktemp /tmp/ea-verify-g.XXXXXX)
      grep -E -i -- "$re" "$NEW" >"$gl" || true
      echo
      echo "== $g ($(nlines "$gl") log lines mention it) =="
      echo "-- info (watchPath / installedStatus / Located files / exePath) --"
      n_info=$(grep -c -E -- "$INFO_RE" "$gl" || true)
      [ "$n_info" -le "$MAXLINES" ] || echo "   ... $((n_info - MAXLINES)) earlier info lines omitted (EA_VERIFY_MAX=$MAXLINES)"
      grep -E -- "$INFO_RE" "$gl" | cut -c1-300 | tail -n "$MAXLINES" || true
      echo "-- ALARM (Download / CalculatingBase / Repair / Verify / NotInstalled / needsRepair / Locate) --"
      n_alarm=$(grep -E -- "$ALARM_RE" "$gl" | grep -vc 'TelemetryManagerV2' || true)
      [ "$n_alarm" -le "$MAXLINES" ] || echo "   ... $((n_alarm - MAXLINES)) earlier alarm lines omitted"
      grep -E -- "$ALARM_RE" "$gl" | grep -v 'TelemetryManagerV2' | cut -c1-300 | tail -n "$MAXLINES" || true
      echo "-- latest installedStatus per softwareId --"
      sed -n 's/.*softwareId=\[\([^]]*\)\].*installedStatus=\[\([^]]*\)\].*/\1=\2/p' "$gl" | awk -F= '{s[$1]=$2; if (!($1 in o)) {o[$1]=++k; n[k]=$1}} END {for (i=1;i<=k;i++) print "   " n[i] " = " s[n[i]]}'
      n_inst=$(grep -c -E 'installedStatus=\[Installed\]' "$gl" || true)
      if [ "$(nlines "$gl")" -eq 0 ]; then verdict="NO DATA (game not mentioned since the mark)"
      elif [ "$n_alarm" -gt 0 ]; then verdict="CHECK ($n_alarm alarm line(s), $n_inst Installed line(s))"
      elif [ "$n_inst" -gt 0 ]; then verdict="LOOKS OK ($n_inst Installed line(s), no alarm line)"
      else verdict="UNKNOWN (mentioned, but no installedStatus and no alarm)"; fi
      echo "-- verdict: $verdict"
      if [ -n "${LABEL}" ] && [ "$APPLY" = 1 ]; then log "check $LABEL: $g: $verdict"; fi
      /bin/rm -f "$gl"
    done
    echo
    echo "== old library paths still referenced in the new bytes (EA Games\\BF4\\ ; Program Files\\EA Games\\Battlefield 3) =="
    grep -E -- "$OLD_PATH_RE" "$NEW" | grep -v -E 'EAInstaller|Cleanup\.exe' | cut -c1-300 | tail -n "$MAXLINES" || echo "   (none)"
    ;;

  wait)
    PATTERN=${REST[0]:-}; TMO=${REST[1]:-}
    [ -n "$PATTERN" ] && [ -n "$TMO" ] || usage
    REST=("${REST[@]:2}")
    LOGNAME_=EADesktop.log
    while [ "${#REST[@]}" -gt 0 ]; do
      case "${REST[0]}" in
        --log) LOGNAME_=${REST[1]:?}; REST=("${REST[@]:2}") ;;
        --since-marker) MARKER=${REST[1]:?}; REST=("${REST[@]:2}") ;;
        *) usage ;;
      esac
    done
    case "$LOGNAME_" in /*) LF=$LOGNAME_ ;; *) LF=$LOGDIR/$LOGNAME_ ;; esac
    off=$(marker_offset "$(basename "$LF")")
    if [ -z "$off" ]; then off=$([ -f "$LF" ] && /usr/bin/stat -f %z "$LF" || echo 0); fi
    TMP=$(/usr/bin/mktemp /tmp/ea-verify-wait.XXXXXX)
    # follow only the bytes written after the marker; work wait --log then sees new lines only
    /usr/bin/tail -c +$((off + 1)) -F "$LF" >"$TMP" 2>/dev/null &
    TP=$!
    trap 'kill "$TP" 2>/dev/null || true; /bin/rm -f "$TMP"' EXIT
    rc=0
    "$WORK" wait --log "$TMP" "$PATTERN" --timeout "$TMO" || rc=$?
    if [ "$APPLY" = 1 ]; then log "wait '$PATTERN' in $(basename "$LF") (timeout ${TMO}s): rc=$rc"; fi
    exit "$rc"
    ;;

  *) usage ;;
esac
