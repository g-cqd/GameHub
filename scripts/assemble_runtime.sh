#!/bin/bash
# Assemble a GameHub runtime from the freshly built fork tree.
# usage: assemble_runtime.sh RUNTIME_DIR      (e.g. /Volumes/ExT2/GameHub/Runtimes/hub-1)
# inputs (override with env):
#   WINE_SDK_OURS  make-installed fork Wine (--enable-archs=i386,x86_64)
#   DXMT_BUILD     meson build dirs x64/ and x32/
#   X87_BIN        built x87sidecar
#   OLD_RT         previous runtime to take compatdb.so and lib/external from
set -euo pipefail
RT=${1:?runtime dir}
S=${WINE_SDK_OURS:-/Volumes/ExT2/GameHub/sdk/wine-ours}
DX=${DXMT_BUILD:-/Volumes/ExT2/GameHub/build/dxmt}
X87=${X87_BIN:-/Volumes/ExT2/GameHub/build/x87sidecar/bin/x87sidecar}
OLD=${OLD_RT:-/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer}
ENT=${ENT:-/Users/gc/Developer/wine/wine-entitlements.plist}
WB=$S/bin/winebuild
CP=/bin/cp

[ ! -e "$RT" ] || { echo "$RT exists" >&2; exit 1; }
mkdir -p "$RT/bin" "$RT/lib/wine" "$RT/share"
# --- base Wine: binaries, unix modules, PE modules (no import libs, no tests)
$CP -c "$S/bin/wine" "$S/bin/wineserver" "$S/bin/winebuild" "$RT/bin/"
$CP -c -R "$S/share/wine" "$RT/share/"
for a in x86_64-unix i386-windows x86_64-windows; do
  mkdir -p "$RT/lib/wine/$a"
  (cd "$S/lib/wine/$a" && for f in *; do case "$f" in *.a|*.pdb) ;; *) $CP -c -R "$f" "$RT/lib/wine/$a/" ;; esac; done)
done
# --- compatdb.so, external libs (freetype/gnutls/SDL), sidecar
$CP -c "$OLD/lib/wine/x86_64-unix/compatdb.so" "$RT/lib/wine/x86_64-unix/"; chflags nouchg "$RT/lib/wine/x86_64-unix/compatdb.so"
$CP -c -R "$OLD/lib/external" "$RT/lib/external"; chflags -R nouchg "$RT"
$CP -c "$X87" "$RT/bin/x87sidecar"
# --- relocate wined3d into its backend dirs, leave fake modules behind
for arch in i386 x86_64; do
  pe=$arch-windows; b=$([ $arch = i386 ] && echo i686-windows || echo x86_64-windows); m=$([ $arch = i386 ] && echo -m32 || echo -m64)
  mkdir -p "$RT/lib/wine/d3d9/wined3d/$pe" "$RT/lib/wine/dxgi/wined3d/$pe" "$RT/lib/wine/d3d9/mtld3d/$pe" "$RT/lib/wine/dxgi/dxmt/$pe"
  mv "$RT/lib/wine/$pe/d3d9.dll" "$RT/lib/wine/d3d9/wined3d/$pe/"
  for d in dxgi d3d10 d3d10_1 d3d10core d3d11; do mv "$RT/lib/wine/$pe/$d.dll" "$RT/lib/wine/dxgi/wined3d/$pe/"; done
  # DXMT PEs; d3d10/d3d10_1 are Wine's own thin forwarders
  [ $arch = x86_64 ] && dx=$DX/x64 || dx=$DX/x32
  for d in dxgi:dxgi d3d11:d3d11 d3d10core:d3d10 winemetal:winemetal; do
    n=${d%%:*}; dir=${d##*:}; $CP -c "$dx/src/$dir/$n.dll" "$RT/lib/wine/dxgi/dxmt/$pe/$n.dll"
  done
  $CP -c "$RT/lib/wine/dxgi/wined3d/$pe/d3d10.dll" "$RT/lib/wine/dxgi/wined3d/$pe/d3d10_1.dll" "$RT/lib/wine/dxgi/dxmt/$pe/"
  for f in "$RT/lib/wine/dxgi/dxmt/$pe"/*.dll; do "$WB" --builtin "$f" >/dev/null 2>&1 || true; done
  for n in d3d9; do "$WB" --fake-module -o "$RT/lib/wine/$pe/$n.dll" -b $b --dll "$RT/lib/wine/d3d9/wined3d/$pe/$n.dll"; done
  for n in dxgi d3d10 d3d10_1 d3d10core d3d11; do "$WB" --fake-module -o "$RT/lib/wine/$pe/$n.dll" -b $b --dll "$RT/lib/wine/dxgi/wined3d/$pe/$n.dll"; done
  "$WB" --fake-module -o "$RT/lib/wine/$pe/winemetal.dll" -b $b --dll "$RT/lib/wine/dxgi/dxmt/$pe/winemetal.dll"
done
mkdir -p "$RT/lib/wine/dxgi/dxmt/x86_64-unix" "$RT/lib/wine/d3d9/mtld3d/x86_64-unix"
$CP -c "$DX/x64/src/winemetal/unix/winemetal.so" "$RT/lib/wine/dxgi/dxmt/x86_64-unix/"
$CP -c "$DX/x64/src/winemetal/unix/winemetal.so" "$RT/lib/wine/x86_64-unix/"
# compatdb.so's built-in steam-web-helper rule asks for dxgi=gptk (D3DMetal, not shipped); without this alias it
# falls back to the placeholder dxgi.dll and steamwebhelper crashes in a restart loop
ln -s dxmt "$RT/lib/wine/dxgi/gptk"
# --- sign (ad-hoc) with the Wine entitlements
for f in "$RT/bin/wine" "$RT/bin/wineserver"; do codesign -s - -f --entitlements "$ENT" "$f" >/dev/null 2>&1; done
echo "base runtime assembled at $RT (mtld3d + media bundle are installed next)"
