#!/bin/bash
# Install the production mtld3d build into a runtime laid out by assemble_runtime.sh
# (same result as mtld3d's `make install` into a lib/wine/d3d9/mtld3d subtree, without needing link archives).
set -euo pipefail
RT=${1:?runtime}; M=${MTLD3D:-/Users/gc/Developer/mtld3d}; WB=$RT/bin/winebuild; CP=/bin/cp
T=$RT/lib/wine/d3d9/mtld3d
for pair in i386-windows:i686-pc-windows-msvc:i686-windows x86_64-windows:x86_64-pc-windows-msvc:x86_64-windows; do
  IFS=: read pe tgt b <<<"$pair"; o=$M/windows/target/$tgt/production
  [ -d "$o" ] || o=$M/windows/target/$tgt/release
  mkdir -p "$T/$pe"
  $CP -c "$o"/{mtld3d,d3d8,d3d9}.dll "$o"/{mtld3d,d3d8,d3d9}.pdb "$T/$pe/"
  for n in d3d8 d3d9 mtld3d; do "$WB" --builtin "$T/$pe/$n.dll"; done
  rm -f "$RT/lib/wine/$pe"/{d3d8,d3d9,mtld3d}.pdb
  for n in d3d8 d3d9 mtld3d; do "$WB" --fake-module -o "$RT/lib/wine/$pe/$n.dll" -b $b --dll "$T/$pe/$n.dll"; done
done
mkdir -p "$T/x86_64-unix"
u=$M/unix/target/x86_64-apple-darwin/production
[ -d "$u" ] || u=$M/unix/target/x86_64-apple-darwin/release
$CP -c "$u/mtld3d.so" "$T/x86_64-unix/"
rm -rf "$T/x86_64-unix/mtld3d.so.dSYM"; $CP -c -R "$u/mtld3d.so.dSYM" "$T/x86_64-unix/" 2>/dev/null || true
echo "mtld3d installed into $T"
