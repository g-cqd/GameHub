# DXMT: bounded staging/dynamic renames on 32-bit (Crysis 3 level-load crash, 0xC0000005)

## What this fixes

Crysis 3 (32-bit) crashes on every level load. Game.log ends at `Registering TPS Extensions...`
and EA reports 0xC0000005. The fault is a write to address 0 in `memcpy`, called from
`d3d11.dll` `MTLD3D11ImmediateContext::Map`.

Cause: while a level loads, the game write-maps a 4 MB staging buffer, writes it, unmaps it and
copies it to a GPU buffer, hundreds of times, without presenting or flushing. Each write map
while the GPU still owes a copy makes DXMT "rename" the staging resource to a fresh 4 MB copy
(src/dxmt/dxmt_staging.cpp). A retired copy is reused only after the GPU finishes with it. The
rename path never flushes, so the pool grows by 4 MB per map: 24, then 155, 404 and 651 blocks
in under a second, committed memory from 1.5 to 3.6 GB, and the largest free block from 2 GB
to 215 MB. On i386 each copy is an `_aligned_malloc`. When that fails, winemetal silently
creates a Metal buffer at a 64-bit address. `get_accessible_or_null()` turns it into NULL and
`Map` copies 4 MB to address 0.

The patched `d3d11.dll`:

1. **Bounds renamed copies in 32-bit processes** (`RenameBudget`, src/dxmt/dxmt_allocation.hpp).
   One resource may hold up to 64 MB of copies, and all resources together up to 512 MB. Past
   that, a staging write map commits the current command buffer and waits for the GPU to retire
   the oldest copy (or to finish with the current one), then reuses it instead of allocating.
   `WRITE_DISCARD` maps of dynamic buffers and dynamic linear textures on the immediate context
   do the same. **64-bit processes are not bounded**, so their behaviour is unchanged.
2. **Fails loudly instead of writing through NULL.** A CPU-placed buffer or linear texture
   that gets no CPU-accessible memory logs one error. `BufferAllocation::mappedMemory()` then
   returns nullptr, instead of an offset from NULL. Staging and dynamic maps on the immediate
   and deferred contexts return `E_OUTOFMEMORY`, staging creation returns `E_OUTOFMEMORY`, and
   a staging rename that gets no memory waits for the GPU.

When the budget is first reached, the log shows this line once:
`warn:  StagingResource: rename budget reached (64 MB of copies of a 4194304-byte resource), waiting for the GPU instead`

Source: commit 1c9e911 on g-cqd/dxmt `development` (214562d), in the detached worktree
/Volumes/ExT2/GameHub/work/dxmt-rtv/src-wt. Not pushed. The same change is in
`0001-fix-dxmt-bound-rename-copies-on-32-bit-and-fail-maps.patch` (`git am` onto 214562d).
This DLL also contains the buffer-RTV fix from 214562d, so it replaces the
hub-0-winemacfs-dxmtrtv d3d11.dll.

## Files

| Path | What |
|---|---|
| x86_64-windows/d3d11.dll | 64-bit DXMT d3d11, Wine-builtin marked |
| i386-windows/d3d11.dll | 32-bit DXMT d3d11, Wine-builtin marked |
| 0001-...patch | the commit |
| test/dx11_staging_rename.cpp, test/staging_rename_test-{i686,x86_64}.exe | regression test (exit 0 = pass, 1 = fail, 3 = fault) |
| test/run_test.sh | runs the test in the throwaway prefix |
| test/before-*.log, test/after-*.log | test output on stock (214562d) and patched DXMT |
| build/cross-*.txt | meson cross files (llvm-mingw 20261006) |
| SHA256SUMS | checksums |

Only `d3d11.dll` changes. dxgi.dll, d3d10*.dll, winemetal.dll and winemetal.so stay as they are
in the runtime. The new DLLs import the same 110 winemetal symbols per arch as the
hub-0-winemacfs-dxmtrtv DLLs. Their import tables are identical.

## Test results (throwaway prefix, runtime clone hub-0-winemacfs-dxmtstg)

`staging_rename_test`: 20 bursts of 300 map(WRITE)/write one dword/unmap/CopyResource cycles on a
4 MB staging buffer, Flush only between bursts. It counts committed private 4 MB regions in its own
address space, then reads the destination back.

| Run | 4 MB regions (peak) | Committed | Readback | Time (total / mean per map) |
|---|---|---|---|---|
| i386 stock, 20x300, first run | 352 | 1477 MB | correct | 3262 ms / 0.544 ms |
| i386 stock, 20x300, warm | 370 | ~1.5 GB | correct | 1170 ms / 0.195 ms (worst burst 322 ms) |
| i386 stock, 2x1000 | - | - | - | **FAULT 0xC0000005, write to 0x00000000** (same as Crysis) |
| i386 patched, 20x300 (2 runs) | **19** | 124 MB | correct | 1166 / 1237 ms, 0.19-0.21 ms (worst burst 72-80 ms) |
| i386 patched, 2x1000 | **19** | 124 MB | correct | 444 ms / 0.22 ms |
| x86_64 stock, 20x300 (warm runs) | n/a (Metal memory) | - | correct | 1625 / 1170 ms |
| x86_64 patched, 20x300 (3 runs) | n/a | - | correct | 1322 / 1246 / 1181 ms |

The 19 regions are the 2 initial buffers plus 16 copies (64 MB) plus 1. On i386 the mean cost
per map is unchanged and the worst burst drops, because no new 4 MB block has to be allocated
and faulted in. x86_64 behaves the same as before (same timings, within noise).
The buffer-RTV regression test (`../dxmt-rtv/20261011-1515/test/rtv_buffer_test-*.exe`) still
passes 7/7 on both architectures with these DLLs.

Crysis 3 itself: see "Crysis 3 check" below.

## Install (into a clone of a runtime, never in place)

```bash
bash -c '
set -euo pipefail
PKG=/Volumes/ExT2/GameHub/work/dxmt-staging/20261011-1831
SRC=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs          # base; left untouched
NEW=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtfix  # pick a new name
(cd "$PKG" && shasum -a 256 -c SHA256SUMS)
test ! -e "$NEW"
/bin/cp -c -R -p "$SRC" "$NEW"
/bin/cp "$PKG/x86_64-windows/d3d11.dll" "$NEW/lib/wine/dxgi/dxmt/x86_64-windows/d3d11.dll"
/bin/cp "$PKG/i386-windows/d3d11.dll"   "$NEW/lib/wine/dxgi/dxmt/i386-windows/d3d11.dll"
shasum -a 256 "$NEW"/lib/wine/dxgi/dxmt/*/d3d11.dll
'
```

A ready clone already exists: `/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtstg`. It is
hub-0-winemacfs-dxmtrtv plus these two DLLs.

Then launch the game with the new runtime's `bin/wine` and a `WINE_COMPATDB` rule selecting
`dxgi=dxmt`, as the recipes already do. The game log shows
`compatdb:   dxgi = dxmt (from .../Runtimes/<new name>/lib/wine/dxgi/dxmt)`.

## Rollback

Point the launcher back at the previous runtime (hub-0-winemacfs-dxmtrtv, hub-0-winemacfs or
hub-0, none of them modified). To restore the previous DLLs inside a clone instead, copy
`hub-0-winemacfs-dxmtrtv/lib/wine/dxgi/dxmt/{x86_64,i386}-windows/d3d11.dll` back over the clone's
copies. Their sha256 values: x86_64 4b41f97f9b1b560f52f685d4198c2c00db91bc6a032560da08a0e5180bbbd948,
i386 625712b97352be865966294323a109a6f3ad238cae10a10d1452ca3aac7f3918. Stock v0.80 (hub-0-winemacfs):
x86_64 7ca382af0eb32d8a432f6efb14d594fefb45673663be1f7e6682254bff885c47, i386
9afc2b3419818618c4c87274435a28935b0df002caa4b9a8d3a88d3dc846b17d. To remove the test clones:

```bash
bash -c 'rm -rf /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtstg /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtstg-base'
```

## Verify (throwaway prefix only)

```bash
bash -c '
T=/Volumes/ExT2/GameHub/work/dxmt-staging/20261011-1831/test
R=/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtstg
~/.agent-harness/bin/work run -- $T/run_test.sh $R i686 /tmp/stg-i686.log            # expect RESULT PASS, peak 19
~/.agent-harness/bin/work run -- $T/run_test.sh $R i686 /tmp/stg-i686-big.log 2 1000 # expect RESULT PASS (stock: FAULT, exit 3)
~/.agent-harness/bin/work run -- $T/run_test.sh $R x86_64 /tmp/stg-x64.log 20 300 100000
'
```

`run_test.sh` uses the prefix /Volumes/ExT2/GameHub/work/dxmt-staging/prefix-test, which is a clone
of the dxmt-rtv throwaway prefix. The test runs on stock DXMT through
`hub-0-winemacfs-dxmtstg-base`, an unmodified clone of hub-0-winemacfs-dxmtrtv.

## Rebuild

```bash
bash -c '
W=/Volumes/ExT2/GameHub/work/dxmt-rtv
for t in x86_64 i686; do
  ninja -C $W/build/$t src/d3d11/d3d11.dll src/d3d11/d3d11.dll.postproc
done'
```

The build directories were set up as described in ../dxmt-rtv/20261011-1515/README.md, with the
same cross files. The test is built with
`i686-w64-mingw32-clang++ -O2 -static -Wl,--large-address-aware dx11_staging_rename.cpp -ld3d11`
(x86_64: same without the linker flag). It is also listed in tests/dx11/meson.build.

## Crysis 3 check

PENDING. See the report. The replay script for the game's new location is
/Volumes/ExT2/GameHub/work/dxmt-staging/crysis_run.sh. Success means three things. Game.log
gets past `Registering TPS Extensions...` and the level loads. The `n4MB` count in
crysis/<tag>-vmq.txt stays at about 16 per staging resource, not hundreds. There is no 0xC0000005.

## What remains

- winemetal (`_MTLDevice_newBuffer`, src/winemetal/unix/winemetal_unix.c:161-168) still falls back
  silently to a Metal-allocated buffer when the caller passed no memory. The DLL now detects
  that, but a winemetal-side error log would make it visible everywhere. Not changed, because
  that is winemetal.so in the runtime.
- Other i386 `aligned_malloc` + `memory.get()` sites are not on this path and are not
  null-checked: dxmt_context.cpp:39-45 (64 KB dummy constant buffer at device creation) and
  dxmt_occlusion_query.hpp:170-180.
- 64-bit processes still grow the rename pool without bound inside one unflushed burst, using
  real memory (300 maps of 4 MB are 1.2 GB). This was left unchanged on purpose.
- Pools never shrink. A resource keeps its copies (up to 64 MB on i386) until it is destroyed,
  as before.
