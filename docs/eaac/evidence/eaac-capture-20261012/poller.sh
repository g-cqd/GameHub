#!/bin/bash
# EAAC capture poller - run id passed as $1 (capture dir)
CAP="$1"
P=/Volumes/ExT2/GameHub/Prefix
GAME="/Volumes/ExT2/GameHub/EA Games/F1 24"
mkdir -p "$CAP/dropped"
WATCH=(
"$P/drive_c/windows/system32/drivers"
"$P/drive_c/Program Files/EA"
"$P/drive_c/ProgramData/EA Desktop/Logs"
"$P/drive_c/ProgramData/Electronic Arts"
"$P/drive_c/ProgramData/EAAntiCheat"
"$P/drive_c/users/crossover/AppData/Roaming/EAAntiCheat.Installer.Tool"
"$P/drive_c/users/crossover/AppData/Local/Temp"
"$P/drive_c/windows/temp"
"$GAME/__Installer"
)
TOP=( "$GAME" "$P/drive_c/ProgramData" )
prevf=""; prevp=""; prevsys=""
cyc=0
echo "[$(date '+%F %T')] poller pid $$ watching: ${WATCH[*]} | top: ${TOP[*]}" >> "$CAP/poller.log"
while true; do
  cyc=$((cyc+1)); ts=$(date '+%F %T')
  curp=$(ps -axo pid,etime,command | grep -iE '(\.exe|wineserver)' | grep -viE 'grep|\.app/Contents/MacOS' | sed 's/^ *//' | sort)
  if [ "$curp" != "$prevp" ]; then
    echo "==== $ts processes ====" >> "$CAP/process-timeline.log"
    diff <(printf '%s\n' "$prevp") <(printf '%s\n' "$curp") | grep -E '^[<>]' >> "$CAP/process-timeline.log"
    prevp="$curp"
  fi
  curf=$(for d in "${WATCH[@]}"; do [ -d "$d" ] && find "$d" -type f -exec stat -f '%m|%z|%N' {} + 2>/dev/null; done | sort)
  for d in "${TOP[@]}"; do [ -d "$d" ] && curf="$curf"$'\n'"$(find "$d" -maxdepth 1 -type f -exec stat -f '%m|%z|%N' {} + 2>/dev/null)"; done
  curf=$(printf '%s\n' "$curf" | sort)
  if [ "$curf" != "$prevf" ]; then
    while IFS= read -r line; do
      f="${line#*|}"; f="${f#*|}"
      [ -e "$f" ] || continue
      echo "$ts NEW/CHANGED: $f ($(stat -f%z "$f" 2>/dev/null) bytes)" >> "$CAP/file-events.log"
      case "$f" in
        *.log|*.txt|*.json) ;;
        *)
          sz=$(stat -f%z "$f" 2>/dev/null || echo 999999999)
          if [ "$sz" -lt 536870912 ]; then
            tag=$(echo -n "$f" | shasum -a 256 | cut -c1-8)
            cp -p "$f" "$CAP/dropped/c${cyc}-${tag}-$(basename "$f")" 2>/dev/null \
              && { echo "$ts COPIED: $f -> dropped/c${cyc}-${tag}-$(basename "$f")"; shasum -a 256 "$f"; } >> "$CAP/file-events.log"
          fi ;;
      esac
    done < <(diff <(printf '%s\n' "$prevf") <(printf '%s\n' "$curf") | grep -E '^>' | sort -u)
    prevf="$curf"
  fi
  netp=$(ps -axo pid,command | grep -iE 'EAAntiCheat|F1_24' | grep -v grep | awk '{print $1}' | tr '\n' ',' | sed 's/,$//')
  if [ -n "$netp" ]; then
    lsof -nP -iTCP -a -p "$netp" 2>/dev/null | grep -v '^COMMAND' | sort > "$CAP/.netcur"
    if ! cmp -s "$CAP/.netcur" "$CAP/.netprev" 2>/dev/null; then
      echo "==== $ts net (pids $netp) ====" >> "$CAP/net-timeline.log"
      cat "$CAP/.netcur" >> "$CAP/net-timeline.log"
      cp "$CAP/.netcur" "$CAP/.netprev"
    fi
  fi
  if [ $((cyc % 10)) -eq 1 ]; then
    sys=$(find "$P" "$GAME" -maxdepth 6 -iname '*.sys*' -type f 2>/dev/null | sort)
    if [ "$sys" != "$prevsys" ]; then
      { echo "==== $ts sys scan ===="; printf '%s\n' "$sys"; } >> "$CAP/sys-scan.log"
      prevsys="$sys"
    fi
  fi
  sleep 2
done
