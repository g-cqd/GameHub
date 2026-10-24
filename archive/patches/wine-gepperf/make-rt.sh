#!/bin/bash
# Build ntdll.so in the runtime-lineage tree, once without the fix (stashed) and once with it.
set -e
W=/Volumes/ExT2/GameHub/work/wine-gepperf
export MACOSX_DEPLOYMENT_TARGET=15.0
export PATH="/Volumes/ExT2/GameHub/toolchains/llvm-mingw-20261006-ucrt-macos-universal/bin:/opt/homebrew/opt/llvm/bin:$PATH"
mkdir -p $W/rt-out/base $W/rt-out/fix
cd $W/rt-src; git stash -q
cd $W/rt-build; make -j"${JOBS:-6}" dlls/ntdll/ntdll.so
cp dlls/ntdll/ntdll.so $W/rt-out/base/ntdll.so
cd $W/rt-src; git stash pop -q; git diff --stat
cd $W/rt-build; make -j"${JOBS:-6}" dlls/ntdll/ntdll.so
cp dlls/ntdll/ntdll.so $W/rt-out/fix/ntdll.so
shasum -a 256 $W/rt-out/*/ntdll.so
