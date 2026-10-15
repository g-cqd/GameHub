#!/bin/bash
# Build only winemac.drv (unix .so and PE .drv) in the winemac-fs build tree.
set -e
cd /Volumes/ExT2/GameHub/work/winemac-fs/build
export MACOSX_DEPLOYMENT_TARGET=15.0
export PATH="/Volumes/ExT2/GameHub/toolchains/llvm-mingw-20261006-ucrt-macos-universal/bin:/opt/homebrew/opt/llvm/bin:$PATH"
make -j"$(sysctl -n hw.ncpu)" dlls/winemac.drv/winemac.so dlls/winemac.drv/x86_64-windows/winemac.drv "$@"
