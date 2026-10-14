#!/bin/bash
# nfs-ea-import-dryrun.sh -- STRICTLY READ-ONLY checker for nfs-ea-import-plan-20261011.md
#
# Writes nothing (stdout/stderr only), starts no wine, creates no directory or temp file, never
# sleeps. It only reads: ps, one `lsof -nP -F n`, stat, find, grep, df, readlink.
#
#   bash nfs-ea-import-dryrun.sh            plan mode: run any time (EA may be running).
#                                           Checks that need EA stopped print EXPECTED-FAIL-NOW.
#   bash nfs-ea-import-dryrun.sh --gate     apply gate: every check must PASS; exit 0 only then,
#                                           exit 2 otherwise.
#
# Last line: DRYRUN <mode> pass=N fail=M expected_fail_now=K
set -u
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
export LC_ALL=C

MODE=plan
case "${1:-}" in
  "" | --plan) ;;
  --gate) MODE=gate ;;
  -h | --help)
    sed -n '2,13p' "$0"
    exit 0
    ;;
  *)
    echo "usage: $0 [--plan|--gate]" >&2
    exit 64
    ;;
esac

# ---- constants (same values as step S0 of the plan) ------------------------------------------
H=/Volumes/ExT2/GameHub
SP=$H/Prefix
OP=$H/Relocated/NFS2015Mac/Data/Prefix
OPALIAS="/Users/gc/Library/Application Support/NFS2015Mac/Data/Prefix"
SPALIAS=$H/Relocated/BF3Mac/Data/Prefix
SPALIAS2="/Users/gc/Library/Application Support/BF3Mac/Data/Prefix"
OLD="$OP/drive_c/Program Files/EA Games/Need for Speed"
NEW="$H/EA Games/Need for Speed"
RT=$H/Runtimes/hub-0-winemacfs-dxmtrtv
PLAN=$H/docs/nfs-ea-import-20261011
REG=$PLAN/nfs-import.reg
SPLIC="$SP/drive_c/ProgramData/Electronic Arts/EA Services/License"
SPLOGS="$SP/drive_c/ProgramData/EA Desktop/Logs"
EXPECT_FILES=144
EXPECT_BYTES=14639595955
MACHASH=d1920624b6654b648e83b7732a233cc23636a0c9
UID_NUM=$(id -u)

PASS=0
FAIL=0
EXPF=0

# result KIND NAME RC [DETAIL]   KIND: static (must always pass) | stop (needs EA stopped)
result() {
  local kind=$1 name=$2 rc=$3 detail=${4-} tag
  if [ "$rc" -eq 0 ]; then
    PASS=$((PASS + 1))
    tag='PASS'
  elif [ "$MODE" = plan ] && [ "$kind" = stop ]; then
    EXPF=$((EXPF + 1))
    tag='EXPECTED-FAIL-NOW'
  else
    FAIL=$((FAIL + 1))
    tag='FAIL'
  fi
  printf '[%s] %s' "$tag" "$name"
  if [ -n "$detail" ]; then
    printf ' -- %s' "$(printf '%s\n' "$detail" | cut -c1-220 | sed '2,$s/^/      | /')"
  fi
  printf '\n'
}
info() { printf '[INFO] %s\n' "$*"; }

# one consistent snapshot of the machine
PS_ALL=$(/bin/ps -axww -o pid=,command= 2>/dev/null)
PS_OTHERS=$(printf '%s\n' "$PS_ALL" | awk -v me="$$" '$1 != me')
LSOF=$(/usr/sbin/lsof -nP -F n 2>/dev/null)

canon() { (cd -P "$1" 2>/dev/null && pwd -P); }

# trim a block of lines to at most N, with a "+M more" tail
head_more() {
  local n=$1 text=$2 total
  total=$(printf '%s\n' "$text" | awk 'END{print NR}')
  printf '%s\n' "$text" | awk -v n="$n" 'NR<=n{print substr($0,1,170)}'
  [ "$total" -gt "$n" ] && printf '(+%s more)\n' "$((total - n))"
  return 0
}

# ---- prefixNotInUse (same logic as gamehub-cli datastore: DatastoreChecks.prefixNotInUse) -----
# no open file under the prefix, no holder of its wine server socket, no command line naming it
check_prefix_idle() {
  local label=$1 path=$2
  shift 2
  local real f a dev ino devhex inohex root dir problems="" notes="" hits joined cd
  local forms=()
  real=$(canon "$path") || {
    result stop "prefixNotInUse $label" 1 "$path does not exist"
    return
  }
  forms=("$real")
  [ "$path" != "$real" ] && forms+=("$path")
  for a in "$@"; do
    [ -e "$a" ] || continue
    case " ${forms[*]} " in *" $a "*) ;; *) forms+=("$a") ;; esac
    cd=$(canon "$a")
    if [ -n "$cd" ]; then
      f=0
      for x in "${forms[@]}"; do [ "$x" = "$cd" ] && f=1; done
      [ "$f" -eq 0 ] && forms+=("$cd")
    fi
  done
  joined=$(printf '%s\n' "${forms[@]}")

  # 1. open files below any form of the prefix path
  if [ -z "$LSOF" ]; then
    problems="lsof printed nothing (cannot tell)"
  else
    hits=$(printf '%s\n' "$LSOF" | FORMS="$joined" awk '
      BEGIN { n = split(ENVIRON["FORMS"], F, "\n") }
      /^n\// { p = substr($0, 2)
               for (i = 1; i <= n; i++) if (p == F[i] || index(p, F[i] "/") == 1) { print p; break } }')
    [ -n "$hits" ] && problems="open files: $(printf '%s\n' "$hits" | awk 'END{print NR}') e.g. $(printf '%s\n' "$hits" | head -2 | tr '\n' ' ')"
  fi

  # 2. wine server socket: /tmp/.wine-<uid>/server-<hex dev>-<hex ino>/socket (dev, ino of the prefix dir)
  set -- $(/usr/bin/stat -f '%d %i' "$real" 2>/dev/null)
  dev=${1:-} ino=${2:-}
  if [ -z "$dev" ] || [ -z "$ino" ]; then
    problems="$problems
could not stat $real"
  else
    devhex=$(printf '%x' "$dev")
    inohex=$(printf '%x' "$ino")
    for root in /tmp /private/tmp; do
      dir="$root/.wine-$UID_NUM/server-$devhex-$inohex"
      [ -e "$dir/socket" ] || continue
      hits=$(printf '%s\n' "$LSOF" | FORMS="$dir
$(canon "$dir")" awk '
        BEGIN { n = split(ENVIRON["FORMS"], F, "\n") }
        /^n\// { p = substr($0, 2)
                 for (i = 1; i <= n; i++) if (F[i] != "" && (p == F[i] || index(p, F[i] "/") == 1)) { print p; break } }')
      if [ -n "$hits" ]; then
        problems="$problems
wine server socket $dir/socket is held ($(printf '%s\n' "$hits" | awk 'END{print NR}') handles)"
      else
        notes="stale wine socket without holder at $dir"
      fi
    done
  fi

  # 3. a process command line naming the prefix
  hits=$(printf '%s\n' "$PS_OTHERS" | FORMS="$joined" awk '
    BEGIN { n = split(ENVIRON["FORMS"], F, "\n") }
    { for (i = 1; i <= n; i++) if (F[i] != "" && index($0, F[i])) { print; break } }')
  [ -n "$hits" ] && problems="$problems
$(printf '%s\n' "$hits" | awk 'END{print NR}') process(es) name the prefix: $(printf '%s\n' "$hits" | head -2 | cut -c1-110 | tr '\n' '|')"

  problems=$(printf '%s' "$problems" | sed '/^$/d')
  if [ -z "$problems" ]; then
    result stop "prefixNotInUse $label" 0 "dev $dev ino $ino ($devhex-$inohex)${notes:+; $notes}"
  else
    result stop "prefixNotInUse $label" 1 "$problems"
  fi
}

echo "== nfs-ea-import dry run, mode=$MODE, $(date -u +%Y-%m-%dT%H:%M:%SZ), host $(uname -n) =="

# ---- S1 stop checks ---------------------------------------------------------------------------
WINE_RE='wineserver|wine-preloader|/bin/wine|x87sidecar|\.exe|NFS2015Launcher|NFS2015Session'
hits=$(printf '%s\n' "$PS_OTHERS" | grep -Ei "$WINE_RE")
if [ -z "$PS_ALL" ]; then
  result stop "noWineProcess" 1 "ps printed nothing (cannot tell)"
elif [ -z "$hits" ]; then
  result stop "noWineProcess" 0 "no process matches /$WINE_RE/"
else
  result stop "noWineProcess" 1 "$(printf '%s\n' "$hits" | awk 'END{print NR}') matching processes:
$(head_more 5 "$hits")"
fi

check_prefix_idle "shared prefix SP (+ Relocated and ~/Library BF3Mac aliases)" "$SP" "$SPALIAS" "$SPALIAS2"
check_prefix_idle "old NFS prefix OP (+ ~/Library alias)" "$OP" "$OPALIAS"

hits=$(printf '%s\n' "$PS_OTHERS" | grep -Ei 'NFS2015Launcher|NFS2015Session|Need for Speed Bundled')
if [ -z "$hits" ]; then
  result stop "old wrapper not running" 0 "no NFS2015Launcher/NFS2015Session/bundle process"
else
  result stop "old wrapper not running" 1 "$(head_more 3 "$hits")"
fi

# ---- game folder ------------------------------------------------------------------------------
OLD_OK=0
if [ -L "$OLD" ]; then
  result static "OLD is a real directory" 1 "$OLD is a symlink"
elif [ -d "$OLD" ]; then
  result static "OLD is a real directory" 0 "$OLD"
  OLD_OK=1
else
  result static "OLD is a real directory" 1 "$OLD missing (already moved?)"
fi

if [ "$OLD_OK" -eq 1 ]; then
  n=$(/usr/bin/find "$OLD" -type f | wc -l | tr -d ' ')
  [ "$n" = "$EXPECT_FILES" ]
  result static "fileCount OLD == $EXPECT_FILES" $? "found $n"

  n=$(/usr/bin/find "$OLD" -type l | wc -l | tr -d ' ')
  [ "$n" = 0 ]
  result static "symlinks under OLD == 0" $? "found $n"

  n=$(/usr/bin/find "$OLD" -type f -links +1 | wc -l | tr -d ' ')
  [ "$n" = 0 ]
  result static "linkCount: all OLD files have 1 link" $? "$n files with more than 1 link"

  bytes=$(/usr/bin/find "$OLD" -type f -print0 | xargs -0 /usr/bin/stat -f %z | awk '{s+=$1} END{print s+0}')
  [ "$bytes" = "$EXPECT_BYTES" ]
  result static "total bytes OLD == $EXPECT_BYTES" $? "found $bytes"

  [ -f "$OLD/NFS16.exe" ]
  result static "NFS16.exe present" $? "$(/usr/bin/stat -f '%z bytes' "$OLD/NFS16.exe" 2>/dev/null)"
  info "directories under OLD (incl. root): $(/usr/bin/find "$OLD" -type d | wc -l | tr -d ' ')"
fi

if [ ! -e "$NEW" ] && [ ! -L "$NEW" ]; then
  result static "NEW absent" 0 "$NEW"
else
  result static "NEW absent" 1 "$NEW already exists"
fi

NEWPARENT=$(dirname "$NEW")
if [ -d "$NEWPARENT" ] && [ ! -L "$NEWPARENT" ] && [ -w "$NEWPARENT" ]; then
  result static "NEW parent exists, is a real dir, writable" 0 "$NEWPARENT"
else
  result static "NEW parent exists, is a real dir, writable" 1 "$NEWPARENT"
fi

d1=$(/usr/bin/stat -f %d "$OLD" 2>/dev/null)
d2=$(/usr/bin/stat -f %d "$NEWPARENT" 2>/dev/null)
d3=$(/usr/bin/stat -f %d "$SP" 2>/dev/null)
[ -n "$d1" ] && [ "$d1" = "$d2" ] && [ "$d1" = "$d3" ]
result static "sameDevice OLD / NEW parent / SP" $? "dev OLD=${d1:-?} NEWparent=${d2:-?} SP=${d3:-?}"

[ "$(readlink "$SP/dosdevices/e:" 2>/dev/null)" = "$H" ]
result static "SP dosdevices e: -> $H" $? "$(readlink "$SP/dosdevices/e:" 2>/dev/null)"
[ "$(readlink "$SP/dosdevices/z:" 2>/dev/null)" = / ]
result static "SP dosdevices z: -> /" $? "$(readlink "$SP/dosdevices/z:" 2>/dev/null)"

# ---- registries -------------------------------------------------------------------------------
n=$(grep -cF 'Need for Speed' "$SP/system.reg" 2>/dev/null)
[ "$n" = 0 ]
result static "shared system.reg has no 'Need for Speed'" $? "$n matching lines"

HDR='[Software\\Wow6432Node\\EA Games\\Need for Speed]'
SEC=$(HDR="$HDR" awk 'index($0,ENVIRON["HDR"])==1{f=1;next} f&&/^\[/{exit} f' "$OP/system.reg" 2>/dev/null)
miss=""
[ -n "$SEC" ] || miss="section header"
for l in '"Install Dir"="C:\\Program Files\\EA Games\\Need for Speed\\"' '"Locale"="en_US"' \
  '"Product GUID"="{F8643E83-A868-4EE8-A0B9-389386830453}"'; do
  printf '%s\n' "$SEC" | grep -qxF "$l" || miss="$miss $l"
done
[ -z "$miss" ]
result static "old system.reg has the Wow6432Node NFS key" $? "${miss:+missing: $miss}"

# ---- licences ---------------------------------------------------------------------------------
if [ ! -e "$SPLIC/1024486.dlf" ]; then
  result static "shared License dir has no 1024486.dlf" 0 "present: $(ls "$SPLIC" 2>/dev/null | grep -v stale | tr '\n' ' ')"
else
  result static "shared License dir has no 1024486.dlf" 1 "$SPLIC/1024486.dlf exists"
fi
info "old prefix licence: $(ls -l "$OP/drive_c/ProgramData/Electronic Arts/EA Services/License/1024486.dlf" 2>/dev/null | awk '{print $5" bytes "$6" "$7" "$8}')"

# ---- space, tools, files ----------------------------------------------------------------------
free_kb=$(/bin/df -k "$H" 2>/dev/null | awk 'NR==2{print $4}')
[ -n "$free_kb" ] && [ "$free_kb" -ge 1048576 ]
result static "free space >= 1 GiB" $? "free $((${free_kb:-0} / 1048576)) GiB ($free_kb KiB); the plan itself copies no game data"

[ -x "$RT/bin/wine" ]
result static "RT/bin/wine executable" $? "$RT/bin/wine"
[ -x "$RT/bin/wineserver" ]
result static "RT/bin/wineserver executable" $? "$RT/bin/wineserver"
[ -x "$H/bin/start-ea.sh" ]
result static "start-ea.sh exists and is executable" $? "$H/bin/start-ea.sh"
[ -x "$HOME/.agent-harness/bin/work" ]
result static "~/.agent-harness/bin/work exists" $? "$HOME/.agent-harness/bin/work"
[ -d "$H/Backups" ] && [ -w "$H/Backups" ]
result static "Backups parent exists and is writable" $? "$H/Backups"
[ -d "$SP/drive_c/ProgramData/EA Desktop" ] && [ -d "$SPLIC" ]
result static "shared EA Desktop + License dirs exist (backup sources)" $? ""

# ---- nfs-import.reg ---------------------------------------------------------------------------
EXPECTED_REG='REGEDIT4

[HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\EA Games\Need for Speed]
"Install Dir"="E:\\EA Games\\Need for Speed\\"
"Locale"="en_US"
"Product GUID"="{F8643E83-A868-4EE8-A0B9-389386830453}"
'
if [ -f "$REG" ]; then
  echo "---- $REG ----"
  sed 's/^/  | /' "$REG"
  echo "---- end ----"
  miss=""
  [ "$(head -1 "$REG")" = "REGEDIT4" ] || miss="$miss header"
  grep -qxF '"Install Dir"="E:\\EA Games\\Need for Speed\\"' "$REG" || miss="$miss InstallDir"
  grep -qxF '"Locale"="en_US"' "$REG" || miss="$miss Locale"
  grep -qxF '"Product GUID"="{F8643E83-A868-4EE8-A0B9-389386830453}"' "$REG" || miss="$miss ProductGUID"
  [ -z "$miss" ]
  result static "nfs-import.reg header + 3 values" $? "${miss:+missing:$miss}"
  nonascii=$(tr -d '\12\40-\176' <"$REG" | wc -c | tr -d ' ')
  [ "$nonascii" = 0 ]
  result static "nfs-import.reg is plain ASCII (no CR, no tabs)" $? "$nonascii odd bytes"
  cmp -s <(printf '%s\n' "$EXPECTED_REG") "$REG"
  result static "nfs-import.reg bytes == expected (ends with a blank line)" $? "$(wc -c <"$REG" | tr -d ' ') bytes"
else
  result static "nfs-import.reg present" 1 "$REG missing"
fi

if [ -d "$SP/drive_c/users/crossover/Documents" ] && [ ! -e "$SP/drive_c/users/crossover/Documents/Need For Speed" ]; then
  result static "S6b target free (shared crossover Documents exists, no 'Need For Speed' yet)" 0 ""
else
  result static "S6b target free (shared crossover Documents exists, no 'Need For Speed' yet)" 1 "$SP/drive_c/users/crossover/Documents"
fi

# ---- info only --------------------------------------------------------------------------------
mh=$(grep -a -o 'machash [0-9a-f]\{40\}' "$SPLOGS/EADesktop.log" 2>/dev/null | tail -1 | awk '{print $2}')
info "EA machash in shared EADesktop.log: ${mh:-<none>} $([ "$mh" = "$MACHASH" ] && echo '(== expected, identical to old prefix)' || echo '(differs from expected!)')"
st=$(grep -a 'IS update: set installInfo for softwareId=\[Origin.SFT.50.0000347\]' "$SPLOGS/EADesktop.log" 2>/dev/null | tail -1 | sed 's/.*installedStatus=\[\([A-Za-z]*\)\].*/\1/')
info "shared installStore last state for Origin.SFT.50.0000347: ${st:-<never mentioned>} (expected NotInstalled before the import)"
inst=$(printf '%s\n' "$PS_OTHERS" | grep -Ei 'touchup\.exe|EAAntiCheat\.Installer|__Installer' | wc -l | tr -d ' ')
info "EA install/touchup processes running now: $inst (this cannot see downloads: pause BF1 and any download in the EA Downloads queue before Quit)"

echo "DRYRUN $MODE pass=$PASS fail=$FAIL expected_fail_now=$EXPF"
if [ "$MODE" = gate ]; then
  [ "$FAIL" -eq 0 ] && exit 0
  exit 2
fi
[ "$FAIL" -eq 0 ] && exit 0
exit 1
