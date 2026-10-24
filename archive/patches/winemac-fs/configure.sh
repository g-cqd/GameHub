#!/bin/bash
# Out-of-tree x86_64 configure of the winemac-fs worktree; only winemac.drv is built from it.
set -e
SRC=/Volumes/ExT2/GameHub/work/winemac-fs/src
BUILD=/Volumes/ExT2/GameHub/work/winemac-fs/build
mkdir -p "$BUILD"
cd "$BUILD"
export MACOSX_DEPLOYMENT_TARGET=15.0
export CC="/usr/bin/clang -arch x86_64"
export CXX="/usr/bin/clang++ -arch x86_64"
export PATH="/Volumes/ExT2/GameHub/toolchains/llvm-mingw-20261006-ucrt-macos-universal/bin:/opt/homebrew/opt/llvm/bin:$PATH"
"$SRC/configure" --host=x86_64-apple-darwin27 --enable-archs=x86_64 --with-mingw=llvm-mingw \
  --disable-tests --without-freetype --without-gnutls --without-sdl --without-usb --without-gstreamer \
  --without-ffmpeg --without-krb5 --without-vulkan --without-cups --without-pcap --without-gphoto \
  --without-sane --without-netapi --without-inotify --without-capi --without-pulse --without-alsa \
  --without-oss --without-dbus --without-fontconfig --without-x --without-wayland --without-gettext \
  --without-opencl --without-v4l2 --without-udev --without-unwind --without-pcsclite
