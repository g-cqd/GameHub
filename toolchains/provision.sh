#!/usr/bin/env bash
# Provision the mtld3d gate toolchain under /Volumes/ExT2/GameHub/toolchains.
# Touches no system path: RUSTUP_HOME/CARGO_HOME live here, the MSVC splat
# lives here (not /opt/xwin), the Wine SDK is an extracted release here.
# Every step logs to $T/logs/<step>.log and records its exit in $T/logs/summary.txt.
set -u
T=/Volumes/ExT2/GameHub/toolchains
export RUSTUP_HOME=$T/rustup CARGO_HOME=$T/cargo
export PATH="$CARGO_HOME/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
DL=$T/downloads
mkdir -p "$T/logs" "$DL"
SUM=$T/logs/summary.txt
: > "$SUM"
step() { local name=$1; shift; local s=$(date +%s); ( set -e; "$@" ) > "$T/logs/$name.log" 2>&1; echo "$name exit=$? secs=$(( $(date +%s)-s ))" >> "$SUM"; }
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
check() { # check <file> <expected-sha256>
  local got; got=$(sha "$1"); echo "sha256 $1 = $got (expected $2)"; [ "$got" = "$2" ]; }
gh_digest() { # gh_digest <repo> <tag> <asset> -> sha256 hex published by GitHub
  gh api "repos/$1/releases/tags/$2" --jq ".assets[] | select(.name==\"$3\") | .digest" | sed 's/^sha256://'; }

RUST_STABLE=1.99.0
RUST_NIGHTLY=nightly-2026-10-02
NEXTEST=0.9.146
XWIN_TOOL=xwin@0.10.0
CRT=14.44.17.14
WSDK=10.0.26100
WINE_REL=cx-26.3.0-5
MINGW=llvm-mingw-20261006-ucrt-macos-universal
MINGW_SHA=a7a19b11048e89372637d26279cdb7c430ed3cf8c1e224310421312bf986ebf6

rustup_init() {
  curl -fsSL -o "$DL/rustup-init" https://static.rust-lang.org/rustup/dist/aarch64-apple-darwin/rustup-init
  curl -fsSL -o "$DL/rustup-init.sha256" https://static.rust-lang.org/rustup/dist/aarch64-apple-darwin/rustup-init.sha256
  check "$DL/rustup-init" "$(cut -d' ' -f1 "$DL/rustup-init.sha256")"
  chmod +x "$DL/rustup-init"
  "$DL/rustup-init" -y --no-modify-path --default-toolchain none --profile minimal
  rustup --version
}
toolchains() {   # mirrors `make setup-rust` (rustup verifies every component against the dist manifest hashes)
  rustup toolchain install "$RUST_STABLE" --profile minimal --component clippy --component llvm-tools
  rustup target add --toolchain "$RUST_STABLE" i686-pc-windows-msvc x86_64-pc-windows-msvc x86_64-apple-darwin aarch64-apple-darwin
  rustup toolchain install "$RUST_NIGHTLY" --profile minimal --component rustfmt
  local bin; bin=$(rustc +"$RUST_STABLE" --print sysroot)/lib/rustlib/aarch64-apple-darwin/bin
  ln -sf "$bin/rust-lld" "$CARGO_HOME/bin/lld-link"
  ln -sf "$bin/llvm-ar" "$CARGO_HOME/bin/llvm-lib"
  rustup toolchain list; rustup +"$RUST_STABLE" target list --installed
}
xwin_tool() { cargo +"$RUST_STABLE" install --locked "$XWIN_TOOL"; xwin --version; }
nextest() {
  local asset="cargo-nextest-$NEXTEST-universal-apple-darwin.tar.gz"
  curl -fsSL -o "$DL/$asset" "https://github.com/nextest-rs/nextest/releases/download/cargo-nextest-$NEXTEST/$asset"
  check "$DL/$asset" "$(gh_digest nextest-rs/nextest "cargo-nextest-$NEXTEST" "$asset")"
  tar zxf "$DL/$asset" -C "$CARGO_HOME/bin"
  cargo-nextest nextest --version
}
xwin_splat() {   # Microsoft's packages, hash-checked by xwin against the channel manifest
  xwin --accept-license --arch x86,x86_64 --crt-version "$CRT" --sdk-version "$WSDK" \
    --cache-dir "$T/xwin-cache" splat --output "$T/xwin"
  xwin --accept-license --arch x86,x86_64 --crt-version "$CRT" --sdk-version "$WSDK" \
    --cache-dir "$T/xwin-cache" list | grep -oE 'Microsoft\.VC\.[0-9.]+\.CRT|Win11SDK_[0-9.]+' | sort -u | tee "$T/xwin/.xwin-packages"
  ls "$T/xwin/crt/lib/x86" "$T/xwin/sdk/lib/um/x86_64" | head
}
llvm_mingw() {
  curl -fsSL -o "$DL/$MINGW.tar.xz" "https://github.com/mstorsjo/llvm-mingw/releases/download/20261006/$MINGW.tar.xz"
  check "$DL/$MINGW.tar.xz" "$MINGW_SHA"
  tar xf "$DL/$MINGW.tar.xz" -C "$T"
  ls "$T/$MINGW/bin/llvm-nm" "$T/$MINGW/aarch64-w64-mingw32/lib/dllcrt2.o" "$T/$MINGW/arm64ec-w64-mingw32/lib/dllcrt2.o"
}
wine_sdk() {     # the wine-build release CI pins (WINE_RELEASE in ci.yml)
  local asset="wine-$WINE_REL-macos-x86_64.tar.xz"
  curl -fsSL -o "$DL/$asset" "https://github.com/athei/wine-build/releases/download/$WINE_REL/$asset"
  check "$DL/$asset" "$(gh_digest athei/wine-build "$WINE_REL" "$asset")"
  mkdir -p "$T/wine-sdk-$WINE_REL"
  tar xf "$DL/$asset" -C "$T/wine-sdk-$WINE_REL"
  # normalise: the tree must hold bin/wine at its top
  local top; top=$(dirname "$(dirname "$(find "$T/wine-sdk-$WINE_REL" -maxdepth 4 -path '*/bin/wine' -type f | head -1)")")
  echo "sdk-root=$top"; echo "$top" > "$T/wine-sdk-root.txt"
  ls "$top/bin"; ls "$top/lib/wine"
  echo "i386 .a: $(ls "$top/lib/wine/i386-windows" | grep -c '\.a$')  x86_64 .a: $(ls "$top/lib/wine/x86_64-windows" | grep -c '\.a$')"
  ls -la "$top/lib/wine/tests/i386-windows/d3d9_test.exe" "$top/lib/wine/tests/x86_64-windows/d3d9_test.exe"
  "$top/bin/wine" --version
}

step rustup-init rustup_init
step toolchains toolchains
step nextest nextest
step xwin-tool xwin_tool
step wine-sdk wine_sdk
step llvm-mingw llvm_mingw
step xwin-splat xwin_splat
du -sh "$T"/* >> "$SUM" 2>&1
echo DONE >> "$SUM"
