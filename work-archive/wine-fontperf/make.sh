#!/bin/bash
# Build only win32u (unix .so) in the wine-fontperf build tree.
set -e
cd /Volumes/ExT2/GameHub/work/wine-fontperf/build
export MACOSX_DEPLOYMENT_TARGET=15.0
export PATH="/Volumes/ExT2/GameHub/toolchains/llvm-mingw-20261006-ucrt-macos-universal/bin:/opt/homebrew/opt/llvm/bin:$PATH"
make -j"${JOBS:-4}" dlls/win32u/win32u.so "$@"
