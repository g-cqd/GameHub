#!/bin/bash
# Out-of-tree x86_64 configure of the runtime-lineage worktree (1a7b0c76 + Hub NFS2015 patches
# 0001-0010 + the ROSETTA_DISABLE_AOT fix); only ntdll.so is built from it. Flags follow
# nfs-macos Packaging/NFS2015Runtime/BUILD.md where they affect ntdll.so (--with-unwind, both
# archs, Apple clang x86_64, macOS 15.0); unrelated host libraries are left out.
set -e
SRC=/Volumes/ExT2/GameHub/work/wine-gepperf/rt-src
BUILD=/Volumes/ExT2/GameHub/work/wine-gepperf/rt-build
mkdir -p "$BUILD"; cd "$BUILD"
export MACOSX_DEPLOYMENT_TARGET=15.0
export CC="/usr/bin/clang -arch x86_64"
export CXX="/usr/bin/clang++ -arch x86_64"
export PATH="/Volumes/ExT2/GameHub/toolchains/llvm-mingw-20261006-ucrt-macos-universal/bin:/opt/homebrew/opt/llvm/bin:$PATH"
"$SRC/configure" --host=x86_64-apple-darwin27 --enable-archs=i386,x86_64 --with-mingw=llvm-mingw \
  --with-unwind --disable-tests --without-gnutls --without-sdl --without-usb --without-gstreamer \
  --without-ffmpeg --without-krb5 --without-vulkan --without-cups --without-pcap --without-gphoto \
  --without-sane --without-netapi --without-inotify --without-capi --without-pulse --without-alsa \
  --without-oss --without-dbus --without-fontconfig --without-freetype --without-x --without-wayland \
  --without-gettext --without-opencl --without-v4l2 --without-udev --without-pcsclite --without-gssapi \
  --without-hwloc
