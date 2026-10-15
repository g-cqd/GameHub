#!/bin/bash
# Replay a Crysis 3 launch on a runtime clone, in the shared prefix, with an EA
# environment dumped from an EA-launched run (envdump.exe), and sample the game's
# address space with vmq2.exe while it loads.
# usage: crysis_run.sh TAG EAENV_FILE [RUNTIME]
# Adapted from /tmp/c3dbg/run.sh for the install's new location (E:\EA Games\Crysis 3).
TAG=$1; EAENV=$2; RT=${3:-/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtstg}
OUT=/Volumes/ExT2/GameHub/work/dxmt-staging/crysis; mkdir -p "$OUT"
R="/Users/gc/Library/Application Support/BF3Mac"
GAME="/Volumes/ExT2/GameHub/EA Games/Crysis 3"
COMPAT="v=3
name=ea-cef;exe=EACefSubProcess.exe;dxgi=wined3d
name=ea-gep;exe=EAGEP.exe;dxgi=wined3d
name=default;exe=*;d3d9=mtld3d;dxgi=dxmt"
EXA=(); while IFS= read -r l; do EXA+=("$l"); done < "$EAENV"
BASE=(env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=en_US.UTF-8 USER=Player HOME="$R/RuntimeHome/Player"
  TMPDIR="$R/Temporary" WINEPREFIX=/Volumes/ExT2/GameHub/Prefix WINEMSYNC=1 MTL_HUD_ENABLED=0 WINEDEBUG=-all,+seh,+timestamp,+pid
  WINE_TF_EMULATION=1 WINE_TF_MAX_STEPS=0 WINE_TF_MAX_NS=0 "WINEDLLOVERRIDES=IGOProxy32.exe=d;winemenubuilder.exe=d"
  ROSETTA_X87_PATH=/Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-fpr/x87sidecar)
cd "$GAME/Bin32" || exit 1
"${BASE[@]}" WINE_COMPATDB="$COMPAT" "$RT/bin/wine" /tmp/c3dbg/envdump/vmq2.exe > "$OUT/$TAG-vmq.txt" 2>&1 &
echo $! > "$OUT/$TAG-vmq.pid"
exec "${BASE[@]}" "${EXA[@]}" WINE_COMPATDB="$COMPAT" "$RT/bin/wine" "E:\\EA Games\\Crysis 3\\Bin32\\Crysis3.exe" > "$OUT/$TAG.log" 2>&1
