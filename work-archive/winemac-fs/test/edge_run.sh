#!/bin/bash
# One D3D11/DXMT full-screen run with a screenshot at t=5 s and an edge report.
# Usage: edge_run.sh <tag> <d3d_fs_test args...>
TAG="$1"; shift
cd /Volumes/ExT2/GameHub/work/winemac-fs/test || exit 1
export WINE_COMPATDB='v=3
name=default;exe=*;d3d9=mtld3d;dxgi=dxmt'
R=/Volumes/ExT2/GameHub/work/winemac-fs/runtime
rm -rf "obs-$TAG"; : > "test-$TAG.log"
./observe_d3d.sh "test-$TAG.log" "obs-$TAG" front > /dev/null 2>&1 &
WINEDEBUG="-all,err+all" ./run.sh "$R" ./d3d/bf4.exe "$@" > "test-$TAG.log" 2>&1
"$R/bin/wineserver" -w
~/.agent-harness/bin/work wait --file "obs-$TAG/shot-t5.png" --timeout 30 > /dev/null
grep "^D3D\|Setting display\|shrunk\|^t= 5s\|^cursor\|SetFullscreenState" "test-$TAG.log"
awk '/=== t5/,/=== after/' "obs-$TAG/observe.txt" | grep "onscreen 1" | sort -u
/tmp/wfs/edges "obs-$TAG/shot-t5.png"
