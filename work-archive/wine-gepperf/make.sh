#!/bin/bash
# Build only the named targets in the wine-gepperf build tree (default: the modules under test).
set -e
cd /Volumes/ExT2/GameHub/work/wine-gepperf/build
export MACOSX_DEPLOYMENT_TARGET=15.0
export PATH="/Volumes/ExT2/GameHub/toolchains/llvm-mingw-20261006-ucrt-macos-universal/bin:/opt/homebrew/opt/llvm/bin:$PATH"
if [ $# -eq 0 ]; then set -- dlls/crypt32/all dlls/wbemprox/all dlls/winemac.drv/all; fi
make -j"${JOBS:-4}" "$@"
