#!/bin/bash
RT=/Volumes/ExT2/GameHub/Runtimes/hub-0-fontperf
R="/Users/gc/Library/Application Support/BF3Mac"
COMPAT='v=3
name=ea-cef;exe=EACefSubProcess.exe;dxgi=wined3d
name=ea-gep;exe=EAGEP.exe;dxgi=wined3d
name=default;exe=*;d3d9=mtld3d;dxgi=dxmt'
L="$1"
start=$(python3 -c 'import time;print(time.time())')
env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=en_US.UTF-8 USER=Player HOME="$R/RuntimeHome/Player" TMPDIR="$R/Temporary" WINEPREFIX=/Volumes/ExT2/GameHub/Prefix WINEDEBUG="${GEP_DEBUG:--all}" WINEMSYNC=1 WINE_TF_EMULATION=1 WINE_TF_MAX_STEPS=0 WINE_TF_MAX_NS=0 WINEDLLOVERRIDES="IGOProxy32.exe=d;winemenubuilder.exe=d" ROSETTA_X87_PATH=/Volumes/ExT2/GameHub/Runtimes/hub-0-helpers/x87sidecar WINE_COMPATDB="$COMPAT" timeout 16 "$RT/bin/wine" 'C:\Program Files\Electronic Arts\EA Desktop\13.805.11.6320-1791598480\EA Desktop\EAGEP.exe' >"$L" 2>&1
echo "start_epoch=$start"
