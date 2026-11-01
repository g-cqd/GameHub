# Request: make AemiKernel and AemiKernels build as Embedded Swift

**For:** the Aemi-Studio/aemi maintainers
**From:** GameHub / WineKit
**aemi revision examined:** `c06c050dd13fa737fac9d173113c727d3212c5b8` (2026-11-01)
**Toolchain:** Swift 6.4.2 (swift-6.4.2-RELEASE), Xcode clang, macOS 27.2 on Apple silicon

## Why

WineKit's `HubRules` library is linked into Wine's `ntdll.so` as a static archive (`libwinekit.a`). Code inside ntdll
can't carry the Swift runtime, Foundation or the stdlib's Unicode tables, so HubRules is built as **Embedded Swift**
and may only depend on libc. HubRules currently has its own copies of about 40 lines that AemiKernel already
provides:

| HubRules today | AemiKernel equivalent |
|---|---|
| `ASCII.firstRange(of:in:)` (strstr) | `ByteSearch.firstRange(of:in:)` |
| `le16` / `le32` in `PEFacts.swift` | `Endian` `loadLE16` / `loadLE32` |
| `ASCII.lower`, case-insensitive compare/prefix | `ASCII` byte helpers, `AemiKernels` ASCII fold |

To use AemiKernel instead of these copies, AemiKernel must build in Embedded mode. Today it doesn't, but only
three files are in the way.

## Findings

Built with:

```
swiftc -target <arch>-apple-macos15 -enable-experimental-feature Embedded -wmo -Osize -parse-as-library \
  -strict-memory-safety -Xfrontend -disable-stack-protector -I <dir with CAemiKernels.h + module.modulemap> \
  -module-name AemiKernels Sources/AemiKernels/*.swift -emit-module -emit-module-path <out> -emit-object -o <out>.o
# then AemiKernel the same way against that module
```

1. **AemiKernels builds as-is** (x86_64 and arm64).
2. **AemiKernel has three blockers:**

   | File | Problem in Embedded |
   |---|---|
   | `ByteBufferPool.swift` | `error: cannot find 'Mutex' in scope`: `Synchronization` isn't available |
   | `ASCII.swift` (`extension Character` only) | `Character` comparisons pull in the stdlib's Unicode/grapheme tables: undefined `__swift_stdlib_getComposition`, `__swift_stdlib_getDecompositionEntry`, `__swift_stdlib_getNormData`, `__swift_stdlib_nfd_decompositions` |
   | `HTTPDateParser.swift` | `String`/`Substring` parsing pulls in the same tables plus `__swift_stdlib_getGraphemeBreakProperty`, `__swift_stdlib_isExtendedPictographic`, `__swift_stdlib_isInCB_Consonant` |

3. **The fix was verified locally on copies.** I left out `ByteBufferPool.swift` and `HTTPDateParser.swift` and cut
   the `extension Character` block from `ASCII.swift`. The remaining 35 files then build in Embedded mode on
   **x86_64 and arm64**. The only undefined symbols left in all of AemiKernel + AemiKernels + CAemiKernels are:
   - x86_64: `__bzero __cpu_indicator_init __cpu_model arc4random_buf free memchr memcpy posix_memalign pthread_once strlen sysctlbyname`
   - arm64: `arc4random_buf bzero free memchr memcpy memset posix_memalign pthread_once strlen sysctlbyname`

   That's libc, plus compiler-rt's `__cpu_model`/`__cpu_indicator_init` on x86_64 (from `__builtin_cpu_supports` in
   `adf_cpu.c`). All of these are acceptable inside ntdll.
4. **A build without SwiftPM needs a module map.** SwiftPM generates CAemiKernels' module map at build time, so a
   plain `swiftc`/`clang` build can't `import CAemiKernels` without writing one by hand. Embedded consumers such as
   WineKit build the sources directly, because SwiftPM can't switch a dependency into Embedded mode.

## Requested changes

1. **Guard the three blockers**, without changing their API for regular builds:
   - wrap `ByteBufferPool.swift` and `HTTPDateParser.swift` in `#if !hasFeature(Embedded)` … `#endif`;
   - wrap only the `extension Character { … }` block of `ASCII.swift` the same way. The `UInt8` statics must stay
     available in Embedded mode.
2. **Ship a module map:** add `Sources/CAemiKernels/include/module.modulemap`:
   ```
   module CAemiKernels {
     header "CAemiKernels.h"
     export *
   }
   ```
   SwiftPM uses a module map it finds in `include/` instead of generating one, so regular builds keep working.
3. **Add an Embedded check to CI**, e.g. `scripts/check-embedded.sh`, run from `ci.yml` on macOS:
   - build AemiKernels, then AemiKernel, with the flags above for `x86_64-apple-macos15` and `arm64-apple-macos15`,
     and compile `Sources/CAemiKernels/*.c` with clang for the same targets;
   - fail if `nm -u` over the objects lists anything outside an allow-list: the libc symbols above plus `__cpu_model`
     and `__cpu_indicator_init`. Any `__swift_stdlib_*` or `swift_*` runtime symbol means a regression.
   - Optional: a Linux leg (`x86_64-unknown-linux-gnu`) in the `swift:6.4.2-noble` container, since WineKit also
     builds there.
4. **Document the rule:** in the AemiKernel/AemiKernels DocC (and CONTRIBUTING if relevant), state that these two
   targets must stay Embedded-clean: no `Synchronization`, Foundation, `Character`/`String` processing,
   existentials or key paths, unless guarded by `#if !hasFeature(Embedded)`.

## Acceptance criteria

- `swift build` and `swift test` for aemi behave as before; no public API is removed for non-Embedded builds.
- `scripts/check-embedded.sh` passes on both macOS architectures, and CI runs it on every PR.
- With only `Sources/CAemiKernels/include` on the include path (no hand-made files), a consumer can build AemiKernels
  and AemiKernel in Embedded mode with the commands above.

## What WineKit does once this lands

WineKit can then pin the new aemi revision, and its `wine-objects` step builds AemiKernels, AemiKernel and CAemiKernels in
Embedded mode into `libwinekit.a`. HubRules can then drop its copies in favour of `ByteSearch`, `Endian` and `ASCII`.
WineKit's differential test against the original C (312 cases) and its mutation gate guard that switch.
