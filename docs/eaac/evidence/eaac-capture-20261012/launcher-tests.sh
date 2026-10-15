#!/bin/bash
CAP="$1"
RT=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv
R="/Users/gc/Library/Application Support/BF3Mac"
EXE='E:\EA Games\F1 24\EAAntiCheat.GameServiceLauncher.exe'
COMPAT='v=3
name=ea-cef;exe=EACefSubProcess.exe;dxgi=wined3d
name=ea-gep;exe=EAGEP.exe;dxgi=wined3d
name=default;exe=*;d3d9=mtld3d;dxgi=dxmt'
X87P=/Volumes/ExT2/GameHub/Runtimes/hub-0-helpers-fpr/x87sidecar
run_test() {
  name="$1"; wd="$2"
  cd "$R" || return
  ( env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=en_US.UTF-8 USER=Player \
      HOME="$R/RuntimeHome/Player" TMPDIR="$R/Temporary" \
      WINEPREFIX=/Volumes/ExT2/GameHub/Prefix WINEMSYNC=1 \
      ROSETTA_X87_PATH="$X87P" WINE_COMPATDB="$COMPAT" WINEDEBUG="$wd" \
      "$RT/bin/wine" "$EXE" > "$CAP/launcher-$name.log" 2>&1 ) &
  pid=$!
  ( sleep 20; kill -9 $pid 2>/dev/null ) &
  wd2=$!
  wait $pid; rc=$?
  kill $wd2 2>/dev/null
  echo "test $name exit=$rc logbytes=$(stat -f%z "$CAP/launcher-$name.log" 2>/dev/null)"
}
run_test C "EAAntiCheat.GameServiceLauncher.exe:trace+module"
run_test A "-all"
run_test B "EAAntiCheat.GameServiceLauncher.exe:trace+relay,EAAntiCheat.GameServiceLauncher.exe:trace+seh,EAAntiCheat.GameServiceLauncher.exe:trace+file,EAAntiCheat.GameServiceLauncher.exe:trace+process,EAAntiCheat.GameServiceLauncher.exe:trace+scm,EAAntiCheat.GameServiceLauncher.exe:trace+service,EAAntiCheat.GameServiceLauncher.exe:trace+virtual,EAAntiCheat.GameServiceLauncher.exe:trace+reg"
