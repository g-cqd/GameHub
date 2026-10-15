#!/bin/bash
# Out-of-tree x86_64 configure of the wine-gepperf worktree; only the modules under test are built.
# Same as work/winemac-fs/configure.sh, but with FreeType (x86_64 Homebrew in /usr/local) and the
# runtime FreeType soname, so load_mac_fonts() and the FreeType backend are compiled in.
set -e
SRC=/Volumes/ExT2/GameHub/work/wine-gepperf/src
BUILD=/Volumes/ExT2/GameHub/work/wine-gepperf/build
mkdir -p "$BUILD"
cd "$BUILD"
export MACOSX_DEPLOYMENT_TARGET=15.0
export CC="/usr/bin/clang -arch x86_64"
export CXX="/usr/bin/clang++ -arch x86_64"
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
export PATH="/Volumes/ExT2/GameHub/toolchains/llvm-mingw-20261006-ucrt-macos-universal/bin:/opt/homebrew/opt/llvm/bin:$PATH"
"$SRC/configure" --host=x86_64-apple-darwin27 --enable-archs=x86_64 --with-mingw=llvm-mingw \
  ac_cv_lib_soname_freetype=@loader_path/../../external/libfreetype.6.dylib \
  FREETYPE_CFLAGS="-I/usr/local/include/freetype2" FREETYPE_LIBS="-L/usr/local/lib -lfreetype" \
  --disable-tests --with-freetype --without-gnutls --without-sdl --without-usb --without-gstreamer \
  --without-ffmpeg --without-krb5 --without-vulkan --without-cups --without-pcap --without-gphoto \
  --without-sane --without-netapi --without-inotify --without-capi --without-pulse --without-alsa \
  --without-oss --without-dbus --without-fontconfig --without-x --without-wayland --without-gettext \
  --without-opencl --without-v4l2 --without-udev --without-unwind --without-pcsclite
