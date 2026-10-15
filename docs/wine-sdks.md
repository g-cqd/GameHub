# Wine SDKs and paths for mtld3d (WINE_SDK, WINE_ARM64, WINE_SDK_ARM64X)

Date: 2026-10-15. The facts below were measured or verified on that day, unless a line says otherwise. This is a reporting document (what exists and what was checked) plus a plan (section 6, not yet run).

## 1. The three fish universal variables

Set with `set -Ux NAME value`; reversible with `set -e NAME`.

| Variable | Value |
|---|---|
| `WINE_SDK` | `/Volumes/ExT2/GameHub/toolchains/wine-sdk-cx-26.3.0-5/wine` |
| `WINE_ARM64` | `/Users/gc/Developer/wine-arm64/install/usr/local` |
| `WINE_SDK_ARM64X` | `/Users/gc/Developer/wine-arm64/sdk-arm64x` |

### WINE_SDK (x86_64 Wine 11.0 SDK)

- `wine --version` = `wine-11.0`. Lineage: athei/wine-build, release 26.3.0-5, built from the athei/wine branch `cx-26-patched`.
- `bin/wine` is Mach-O x86_64, sha256 `7202d5f87ba9542f915b8a886ef7707fd0213200972e4cf61504c514b5e301c4`.
- Layout:
  - `bin/`: function_grep.pl, widl, wine, winebuild, winecpp, winedump, wineg++, winegcc, winemaker, wineserver, wmc, wrc
  - `include/`, `share/`
  - `lib/wine/`: d3d9, dxgi, i386-windows, tests, x86_64-unix, x86_64-windows
  - `lib/wine/tests/{i386-windows,x86_64-windows}/d3d9_test.exe` are present.
- Size: 1.2 GB.
- mtld3d e2e baseline on it: 1263/1277 passed.
- Needed by every mtld3d target; the Makefile errors with "WINE_SDK is not set" otherwise. `make install` and the test legs install into it. The mtld3d Makefile variables `D3D9_TEST_i686` and `D3D9_TEST_x86_64` read `$(WINE_SDK)/lib/wine/tests/{i386,x86_64}-windows/d3d9_test.exe` for `make conformance`.

### WINE_ARM64 (arm64 Wine tree)

A directory holding `bin/wine` and `lib/wine`.

**Important:** `wine-arm64/install` is a DESTDIR-style install, so the real tree root is `install/usr/local`, not `install/`. Verified: the Makefile guard `ARM64_REQUIRE_RUNTIME` rejects `.../wine-arm64/install` with "is not an arm64 Wine tree: it needs bin/wine, bin/wineserver and lib/wine/aarch64-windows" and accepts `.../install/usr/local`.

- `bin/wine`, `wineserver`, `winebuild` are Mach-O 64-bit arm64. `bin/wine --version` = `wine-11.0`. sha256 of `bin/wine`: `dd0db92a219f8de32ce186e4d317bce3430ded1398209fff130c348149610a22`.
- Source: the wine-arm64 repo (`/Users/gc/Developer/wine-arm64`, branch `arm64-macos`): native arm64 macOS Wine 11.0 plus CodeWeavers patches, athei `cx-26-patched` base rebased, configured `--enable-archs=aarch64,i386` with llvm-mingw 20261006. See its `docs/BRINGUP.md`. About 1.6 GB installed; about 35 min to build at -j3 on a loaded machine.
- `lib/wine` contains `aarch64-unix` (30 files), `aarch64-windows` (1008 files, including `libntdll.a` and `d3d9.dll`) and `i386-windows` (1061 files). There is no `x86_64-windows` directory (no x86_64 PE build).
- Status per BRINGUP.md: milestone M1 (native arm64 PE runs, no Rosetta). 32-bit/x86 execution (WoW64 BTCpu, milestone M2) does not exist yet, so the x86 (i686/x86_64) arm64-runtime test legs cannot execute x86 code on it yet.
- It also runs through the signed launcher `host/exec4k` (4 KiB page process); `wine --version` works without it.
- Read by the install, test, conformance and bench targets under `EC=1` or `ARM64=1`, and always by `make bench-variants`. Legs run on private clones (`clone_tree`) of it and never write into it, except the installs.
- The Makefile guard accepts it (checked by running the `ARM64_REQUIRE_RUNTIME` recipe through an auxiliary makefile: "ARM64_REQUIRE_RUNTIME ok").

### WINE_SDK_ARM64X (ARM64X link archives)

A tree holding Wine's two ARM64X link archives at `lib/wine/aarch64-windows/libwinecrt0.a` and `lib/wine/aarch64-windows/libntdll.a`.

- Verified layout: `sdk-arm64x/lib/wine/aarch64-windows/{libntdll.a, libwinecrt0.a}` (ar archives). The `lib` entry is a real nested directory, so no staging copy was needed.
- sha256:

  | File | sha256 | Same as install/usr/local copy? |
  |---|---|---|
  | `libntdll.a` | `a371652d13ec110976abe097f003f43d426d74e317c0d0e89c85c7b4aa0e79f4` | Yes |
  | `libwinecrt0.a` | `9359f32e8a76f606b4c2721dd88f68fc6844f88fe6527aa836ee8def16af4a53` | No (install copy: `b56bac0d875c080cd3840caaf9cac7bf24f8aa19ef52b626ce51071542fe225d`) |

  Do not substitute the install tree for this one.
- `sdk-arm64x/` is git-ignored in wine-arm64 (`.gitignore`). It is produced by wine-arm64, not by wine-build. The x86 Wine SDK carries neither archive.
- Read by the `EC=1` build (`windows-arm64x`, whose link takes `libntdll.a`; cargo build scripts read `WINE_SDK=$WINE_SDK_ARM64X`) and by the `EC=1 make check` clippy leg. The guard `ARM64X_REQUIRE_CARGO` checks that both files exist.

## 2. Which target reads which path

Mirrors the section "Which target reads which path" of mtld3d `docs/BUILDING.md`.

| Path | Read by |
|---|---|
| `LLVM_MINGW`, `ARM64X_LLD` | `EC=1` build |
| `WINE_SDK_ARM64X` | `EC=1` build and `EC=1 make check` |
| `WINE_ARM64` | install, test and conformance under either switch (`EC=1` or `ARM64=1`); bench and bench-ab under either switch; always by `bench-variants` |
| (none of the above runtime paths) | `EC=1 make` and `EC=1 make check` run without `WINE_ARM64` |

## 3. Verification status

- `WINE_ARM64`: the guard passes.
- `WINE_SDK_ARM64X`: the archive-existence part of `ARM64X_REQUIRE_CARGO` passes. The same guard stops earlier on a different missing prerequisite on this machine: the Rust targets `aarch64-pc-windows-msvc` and `arm64ec-pc-windows-msvc` are not installed for toolchain stable. Fix: `make EC=1 setup-rust`.
- `LLVM_MINGW` and `ARM64X_LLD` are unset (optional next step: set them to the candidates below).
  - Candidate `LLVM_MINGW=/Volumes/ExT2/GameHub/toolchains/llvm-mingw-20261006-ucrt-macos-universal`. Its aarch64 `dllcrt2.o` has an ARM64EC half, and release 20261006 is >= the required 20260826.
  - Candidate `ARM64X_LLD=/Volumes/ExT2/GameHub/toolchains/llvm-mingw-20261006-ucrt-macos-universal/bin/lld-link`. It needs an `lld-link` >= 23; this one reports "LLD 23.1.3", which meets that. Homebrew `lld` is not installed.
- A full `EC=1` build was NOT run (shared, busy machine). Only the dry run `make -n EC=1 install-windows-arm64x` was done; it expands correctly to use `sdk-arm64x`.
- Caveat: the `ARM64=1` legs (x86 DLLs under `WINE_ARM64`) will install but cannot run x86 code until wine-arm64 reaches M2.

## 4. What each tree is not: the shipped GameHub runtime

`/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer` (the default of `bin/wine-query.sh`) is a runtime, not an SDK.

- `bin/` holds only `wine` (Mach-O x86_64, sha256 `efe44f4eb5aa258185e56237ba060e1670a9eb4dd84485da63239ad5436cd989`), `wineserver` and `x87sidecar`. `lib/` has `external` and `wine`.
- No `winebuild`, no PE link archives, no `include/`, no tests. It cannot be used as `WINE_SDK`.
- Its version string is deliberately hidden: `--version` prints `eaac-job475-fb185cd9`.

## 5. How the cx SDK relates to our fork

The SDK comes from athei/wine-build's release, built from athei/wine `cx-26-patched` (Wine 11.0 stable `db11d0fe6a` plus CrossOver patches). The upstream tip folded into our fork is `93429c6e7c8` "loader: Substitute Menlo for Lucida Console."

Our fork g-cqd/wine (`/Users/gc/Developer/wine`, branch `main`, HEAD `b8d5aa4d36002ca01a3c6ee48d5e53eef20e34a8`) contains that commit as an ancestor (merge `d0953441aba` on 2026-10-14) plus 72 commits / 46 files (+5844/-200) on top. It is a superset. Examples of what the fork adds:

- Raw Windows syscall emulation for native code on macOS (`db3638ac4ef`, `3001c1d24ed`, `f3e3d1fb3b1`, `412c2688206`, `e9f7fa6662d`, `53789cf8432`). A SIGSYS handler maps Windows 19045 syscall numbers to wine syscall ids via the ntdll stub table.
- Optional Rosetta executable-page toggles and W^X emulation (`7c766d96eaa`, `a5e37e9aeca`, `f77872f277c`, `e82dc1e04ec`).
- kernelbase crash diagnostics (`2cb1ef24e41`, `78ec5a33944`).

Policy in its `UPSTREAM.md`: `main` only, never force-push, upstream merged with merge commits.

The differences matter only when behaviour on the fork SDK differs from the cx SDK, so the cx SDK stays the e2e baseline.

## 6. Plan: a second SDK from our own repo (NOT YET RUN)

**Caveat (stated by the owner):** the fork's raw-syscall stub rewrite fires on any execute fault. Any failure observed on the fork-built SDK must be triaged against that rewrite first (compare against the cx SDK baseline of 1263/1277) before blaming mtld3d.

### Paths

| Item | Path |
|---|---|
| Source | `/Users/gc/Developer/wine` |
| Out-of-tree build dir (default) | `/Volumes/ExT2/GameHub/build/wine` |
| Install prefix (proposal) | `/Volumes/ExT2/GameHub/sdk/wine-ours` |

### What a complete SDK for mtld3d must contain

- `bin/wine`, `bin/winebuild`, `bin/wineserver` (plus winegcc, widl, etc. from `make install`)
- `lib/wine/i386-windows` and `lib/wine/x86_64-windows`, including the PE link archives (`lib*.a`) and builtin dlls
- `lib/wine/x86_64-unix` (the .so modules)
- `lib/wine/tests/i386-windows/d3d9_test.exe` and `lib/wine/tests/x86_64-windows/d3d9_test.exe` (for `make conformance`)
- `include/`

Reference size: the cx SDK is 1.2 GB.

### State as of 2026-10-15 (by inspection)

Another task (scope wine-move) is finishing the wine relocation.

- `/Users/gc/Developer/wine` has an UNCOMMITTED modification of `build-macos-x86_64.sh` (78 insertions, 6 deletions). It adds `WINE_BUILD_DIR` support: `.`/`in-tree`, a path, or unset (in-tree if already configured there, else `/Volumes/ExT2/GameHub/build/wine`); it refuses an unmounted `/Volumes/<name>`. It also adds `WINE_BUILD_JOBS` (default `hw.ncpu`) and subcommands `configure|make|run|builddir`. The last commit is `b8d5aa4d360` "docs: UPSTREAM.md ...".
- `/Volumes/ExT2/GameHub/build/wine` is already CONFIGURED (52 MB: `config.status`, `Makefile`, no binaries) with `configure --host=x86_64-apple-darwin27 --enable-archs=x86_64`, run from `/Users/gc/Developer/wine`. A configure takes about 1 min 47 s (measured from the work log).
- **Gap:** the script hard-codes `--enable-archs=x86_64` only, and `PE_ARCHS` in that configure is only x86_64, so it would produce NO `lib/wine/i386-windows`. The SDK needs both, so reconfigure with `--enable-archs=i386,x86_64`. The script appends `"$@"` after its own flag and the later `--enable-archs` wins in autoconf, but verify via `builddir`/`config.log` that `PE_ARCHS=' i386 x86_64'` after configuring.
- The script has no install subcommand: install goes through `./build-macos-x86_64.sh make install`, and the prefix should be fixed at configure time with `--prefix`.
- The PE compiler is clang from `/opt/homebrew/opt/llvm` (PATH set by the script). Homebrew llvm, llvm@15 and llvm@23 are present; no mingw-w64 gcc is installed. x86_64 Homebrew deps live in `/usr/local`.

### Command sequence (NOT YET RUN)

Run it through the scheduler (`work run`) on this shared machine.

```sh
cd /Users/gc/Developer/wine && git status   # confirm build-macos-x86_64.sh with WINE_BUILD_DIR support is committed
export WINE_BUILD_DIR=/Volumes/ExT2/GameHub/build/wine
/Users/gc/.agent-harness/bin/work run --weight 2 -- ./build-macos-x86_64.sh configure --enable-archs=i386,x86_64 --prefix=/Volumes/ExT2/GameHub/sdk/wine-ours
grep PE_ARCHS $WINE_BUILD_DIR/config.log        # expect ' i386 x86_64'
WINE_BUILD_JOBS=6 /Users/gc/.agent-harness/bin/work run --weight 6 -- ./build-macos-x86_64.sh make
/Users/gc/.agent-harness/bin/work run --weight 4 -- ./build-macos-x86_64.sh make dlls/d3d9/tests/x86_64-windows/d3d9_test.exe dlls/d3d9/tests/i386-windows/d3d9_test.exe
./build-macos-x86_64.sh make install
mkdir -p /Volumes/ExT2/GameHub/sdk/wine-ours/lib/wine/tests/{i386,x86_64}-windows
cp -c $WINE_BUILD_DIR/dlls/d3d9/tests/i386-windows/d3d9_test.exe   /Volumes/ExT2/GameHub/sdk/wine-ours/lib/wine/tests/i386-windows/
cp -c $WINE_BUILD_DIR/dlls/d3d9/tests/x86_64-windows/d3d9_test.exe /Volumes/ExT2/GameHub/sdk/wine-ours/lib/wine/tests/x86_64-windows/
# then verify completeness: bin/{wine,winebuild,wineserver}, lib/wine/{i386-windows,x86_64-windows,x86_64-unix},
# libntdll.a in both PE dirs, include/, tests; `file bin/wine` = x86_64
# use: WINE_SDK=/Volumes/ExT2/GameHub/sdk/wine-ours make ...
# (do not overwrite the fish universal WINE_SDK until a baseline run matches 1263/1277)
```

Unverified: the `d3d9_test.exe` target names are inferred from the old in-tree Makefile (the target `dlls/d3d9/tests/x86_64-windows/d3d9_test.exe` exists there), and the i386 one needs the i386 PE configure. Treat both as unverified.

The old in-tree build in `/Volumes/ExT2/GameHub/src/wine` (x86_64-only, configured 2026-10-14 15:25, has `d3d9_test.exe` for x86_64 only) is the only measured footprint.

### Estimates

| Item | Estimate | Basis |
|---|---|---|
| Disk, build output | about 4.5-5.5 GB | Old in-tree x86_64-only tree: 4.8 GB total = 1.3 GB .git + about 0.33 GB source + about 3.1-3.5 GB build output. The arm64 (aarch64+i386) build was 5.4 GB. |
| Disk, install | about 1.2-1.6 GB | cx SDK is 1.2 GB; wine-arm64 install is 1.6 GB. ExT2 has 228 GB free. |
| Build time | 25-45 min at 6 jobs, plus a few minutes for the two test executables and install | wine-arm64 took about 35 min at -j3 on a loaded machine. No clean measurement exists for this tree (old in-tree object timestamps span 42 h, so they are useless). Assumes this 10-core machine under its normal load of 10+. |
| Configure | 1 min 47 s | Measured. |

## 7. Reverting and using

- Revert: `set -e WINE_ARM64; set -e WINE_SDK_ARM64X` (and `set -e WINE_SDK` to remove the x86 SDK variable).
- Per-invocation override: `WINE_SDK=... make`.
- The variables are fish universal. They are not visible to bash tools unless exported by the shell that launches them.
