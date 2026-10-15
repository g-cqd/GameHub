#!/bin/bash
# Usage: start-ea.sh [game]
#   game (optional): a known shortcut name that, once EA Desktop finishes
#   booting, fires the same origin2://game/launch/ trick a user would get by
#   clicking Play in the EA Desktop UI -- no need to remember the raw URL,
#   offer ID or contentId. Currently supported:
#     nfs2015 | nfs-2015 | needforspeed   -> Need for Speed (2015), NFS16.exe
#   Game launches go through EALauncher.exe and need EA Desktop's client
#   catalog cache primed first (see docs/nfs2015-stale-login-fix-20261015.md);
#   this script fires one priming call with the EA offerId, waits for EA
#   Desktop's own catalog-sync log line, then fires the real contentId. Do
#   not skip the prime step or call EALauncher before EA Desktop is fully
#   authenticated -- both are reproducible ways to get a dropped launch or a
#   stale/incomplete session handoff into the game (see that doc).
# Runtime: $HUB_RUNTIME, default /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer (winemac-fs + DXMT rtv, no Wine version string)
RT="${HUB_RUNTIME:-/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer}"
HUB_GAME="${1:-}"
case "$HUB_GAME" in
  nfs2015|nfs-2015|needforspeed)
    HUB_GAME_PRIME_ID="Origin.OFR.50.0000810"   # NFS 2015 offerId, used only to prime EA Desktop's client catalog cache
    HUB_GAME_CONTENT_ID="1024486"               # NFS 2015 contentId, this is what actually launches NFS16.exe
    HUB_GAME_LABEL="Need for Speed (2015)"
    ;;
  "")
    ;;
  *)
    echo "start-ea.sh: WARNING: unknown game shortcut '$HUB_GAME' -- starting EA Desktop only (no game will be auto-launched)" >&2
    ;;
esac
R="/Users/gc/Library/Application Support/BF3Mac"
EA_ROOT="/Volumes/ExT2/GameHub/Prefix/drive_c/Program Files/Electronic Arts/EA Desktop"
EXE=""
# Updates remove the previous version; select the newest installed executable.
while IFS= read -r candidate; do
  if [ -f "$candidate" ]; then EXE="$candidate"; fi
done < <(printf '%s\n' "$EA_ROOT"/[0-9]*/'EA Desktop'/EADesktop.exe | /usr/bin/sort -V)
if [ -z "$EXE" ]; then
  echo "EA Desktop executable not found under $EA_ROOT" >&2
  exit 1
fi
EA_EXE_UNIX="$EXE"
EXE="C:${EXE#*/drive_c}"
EXE="${EXE//\//\\}"
if [ ! -x "$RT/bin/wine" ]; then
  echo "Wine executable not found: $RT/bin/wine" >&2
  exit 1
fi
_hub_old_umask=$(umask); umask 077
_hub_logdir="/Volumes/ExT2/GameHub/Hub/Logs"
mkdir -p "$_hub_logdir"
ts=$(date +%Y%m%d-%H%M%S); log="$_hub_logdir/ea-$ts.log"
: >> "$log"
chmod 600 "$log" 2>/dev/null || true
umask "$_hub_old_umask"
COMPAT='v=3
name=ea-cef;exe=EACefSubProcess.exe;dxgi=wined3d
name=ea-gep;exe=EAGEP.exe;dxgi=wined3d
name=default;exe=*;d3d9=mtld3d;dxgi=dxmt'
X87P="${HUB_X87_PATH:-/Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-fpr/x87sidecar}"
if [ "${HUB_X87:-on}" = off ]; then X87A=("ROSETTA_X87_PATH="); else X87A=("ROSETTA_X87_PATH=$X87P"); fi
cd "$R" || exit 1
# S4: warn when trace channels that can record credentials are enabled
_hub_warn_winedebug() {
    local spec="$1" item chan risky=""
    local IFS=','
    set -f
    for item in $spec; do
        case "$item" in
            *-*) continue ;;              # "-chan" / "class-chan" disables a channel
        esac
        chan="${item##*+}"                # strip optional "class+" or "+" prefix
        case "$chan" in
            relay|file|reg|environ|all) risky="$risky $chan" ;;
        esac
    done
    set +f
    if [ -n "$risky" ]; then
        printf '%s\n' "start-ea.sh: WARNING: HUB_WINEDEBUG enables high-risk trace channel(s):$risky" \
            "start-ea.sh: WARNING: these traces can record tokens, cookies and credentials; treat the log as secret." >&2
    fi
}
_hub_warn_winedebug "${HUB_WINEDEBUG:--all}"
# S6: verify Authenticode signature of the selected EA Desktop binary (warn-only)
_hub_verify_ea_exe() {
    local exe="$1" out sum
    if [ ! -f "$exe" ]; then
        printf '%s\n' "start-ea.sh: WARNING: selected EADesktop.exe not found: $exe" >&2
        return 0
    fi
    sum=$(shasum -a 256 "$exe" 2>/dev/null | awk '{print $1}')
    printf '%s\n' "start-ea.sh: selected EA Desktop binary: $exe (sha256 ${sum:-unknown})" >&2
    if command -v osslsigncode >/dev/null 2>&1; then
        if out=$(osslsigncode verify -in "$exe" 2>&1) && printf '%s' "$out" | grep -q 'Electronic Arts'; then
            printf '%s\n' "start-ea.sh: Authenticode signature OK (Electronic Arts) for $exe" >&2
        else
            printf '%s\n' "start-ea.sh: WARNING: Authenticode verification FAILED or signer is not Electronic Arts for $exe -- continuing anyway" >&2
        fi
    else
        printf '%s\n' "start-ea.sh: WARNING: cannot verify Authenticode signature (osslsigncode not installed: brew install osslsigncode) -- launching $exe unverified" >&2
    fi
    return 0
}
_hub_verify_ea_exe "$EA_EXE_UNIX"
nohup env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=en_US.UTF-8 USER=Player HOME="$R/RuntimeHome/Player" TMPDIR="$R/Temporary" WINEPREFIX="/Volumes/ExT2/GameHub/Prefix" WINEDEBUG="${HUB_WINEDEBUG:--all}" WINEMSYNC=1 MTL_HUD_ENABLED=0 WINE_TF_EMULATION=1 WINE_TF_MAX_STEPS=0 WINE_TF_MAX_NS=0 WINEDLLOVERRIDES="IGOProxy32.exe=d;winemenubuilder.exe=d" "${X87A[@]}" WINE_COMPATDB="$COMPAT" "$RT/bin/wine" "$EXE" --in-process-gpu >"$log" 2>&1 &
echo "started pid $! log $log"

# S-game: optional post-boot game auto-launch (see usage comment at top).
if [ -n "${HUB_GAME_CONTENT_ID:-}" ]; then
  EA_LAUNCHER_DIR="${EA_EXE_UNIX%/*}"
  EA_LAUNCHER_EXE="C:${EA_LAUNCHER_DIR#*/drive_c}/EALauncher.exe"
  EA_LAUNCHER_EXE="${EA_LAUNCHER_EXE//\//\\}"
  (
    PATH=/usr/bin:/bin:/usr/sbin:/sbin
    fire_launcher() {
      env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=en_US.UTF-8 USER=Player HOME="$R/RuntimeHome/Player" TMPDIR="$R/Temporary" WINEPREFIX="/Volumes/ExT2/GameHub/Prefix" WINEDEBUG=-all WINEMSYNC=1 "$RT/bin/wine" "$EA_LAUNCHER_EXE" "origin2://game/launch/?offerIds=$1" >/dev/null 2>&1
    }
    # Wait for EA Desktop to finish booting (authenticated SPA load), not just
    # for the process to exist -- firing EALauncher before this silently
    # drops the launch request. 90s timeout matches observed cold-boot time.
    for _ in $(seq 1 90); do
      grep -q "SPA load success" "$log" 2>/dev/null && break
      sleep 1
    done
    # Prime EA Desktop's client catalog cache with the public offerId first;
    # the direct contentId launch is silently dropped on a cold cache. Both
    # steps and the reason are documented in
    # docs/nfs2015-stale-login-fix-20261015.md.
    fire_launcher "$HUB_GAME_PRIME_ID"
    sleep 15
    fire_launcher "$HUB_GAME_CONTENT_ID"
    echo "start-ea.sh: auto-launched $HUB_GAME_LABEL (contentId $HUB_GAME_CONTENT_ID)" >> "$log"
  ) &
  echo "start-ea.sh: will auto-launch $HUB_GAME_LABEL once EA Desktop finishes booting (watch $log)"
fi
