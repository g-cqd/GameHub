#!/bin/bash
# Start the Windows Steam client in the shared GameHub prefix.
# Runtime: hub-0 dxmtrtv (mtld3d d3d9 + dxmt dxgi via compatdb defaults, x87sidecar auto-enabled from bin/).
# Usage: start-steam.sh [extra steam args]     Env: HUB_RUNTIME, HUB_WINEDEBUG
set -u
H=/Volumes/ExT2/GameHub
RT=${HUB_RUNTIME:-$H/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer}
LOG=$H/Hub/Logs/steam-$(date +%Y%m%d-%H%M%S).log
mkdir -p "$H/Hub/Logs" "$H/Hub/Temp"
COMPAT='v=3
name=steam-webhelper;exe=steamwebhelper.exe;dxgi=dxmt
name=default;exe=*;d3d9=mtld3d;dxgi=dxmt'
env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=en_US.UTF-8 USER=Player \
  HOME="$H/Hub/Home/Player" TMPDIR="$H/Hub/Temp" \
  WINEPREFIX="$H/Prefix" WINEDEBUG="${HUB_WINEDEBUG:--all}" WINEMSYNC=1 \
  WINE_COMPATDB="$COMPAT" \
  nohup "$RT/bin/wine" 'E:\Library\Steam\steam.exe' -no-cef-sandbox "$@" >"$LOG" 2>&1 &
echo "started pid $! log $LOG"
