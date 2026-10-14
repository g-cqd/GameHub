#!/bin/bash
B="${HUB_RUNTIME:-/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs}/bin/wine"
R="/Users/gc/Library/Application Support/BF3Mac"
for p in "$@"; do
  echo "=== dir $p"
  timeout 90 env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=en_US.UTF-8 USER=Player HOME="$R/RuntimeHome/Player" TMPDIR="$R/Temporary" WINEPREFIX="/Volumes/ExT2/GameHub/Prefix" WINEDEBUG=-all WINEMSYNC=1 WINE_TF_EMULATION=1 WINE_TF_MAX_STEPS=0 WINE_TF_MAX_NS=0 WINEDLLOVERRIDES="IGOProxy32.exe=d;winemenubuilder.exe=d" "$B" cmd /c dir "$p" 2>&1 | tr -d '\r' | grep -v '^compatdb' | tail -3
done
