---
status: accepted
date: 2026-10-31
---

# 0019: Apple's D3DMetal is a local, per-program backend, never shipped

## Context
Some D3D12 games need more than DXMT's D3D12 offers. HITMAN 3, for one, needs DXIL wave operations, which DXMT's
converter lacks. Apple's D3DMetal, from the Game Porting Toolkit, is the most complete D3D12 on macOS. Its licence is
an evaluation licence: no redistribution.

The obvious place for it was the `gptk` backend directory. But compatdb.so's built-in rule sends
`steamwebhelper.exe` to `gptk`. With D3DMetal there, Steam's web helper crash-looped (an illegal instruction in a
system framework, over a million crash lines) and Steam never logged on.

## Decision
- **Where it lives:** D3DMetal is installed exactly as CrossOver ships it, taken from a CrossOver Wine build
  (`toolchains/wine-sdk-cx-26.3.0-5`, D3DMetal 4.0b2):
  - CrossOver's `dxgi/gptk` glue goes in `lib/wine/dxgi/d3dmetal`. The PE DLLs are copied; each
    `x86_64-unix/*.so` is a symlink to `../../../../external/libd3dshared.dylib`.
  - `libd3dshared.dylib` and `D3DMetal.framework` go in `lib/external`.

  `assemble_runtime.sh` does this with `CX_SDK`. `gptk` stays an alias of DXMT, because compatdb.so's built-in
  rule sends `steamwebhelper.exe` to `gptk`, and Steam's web helper crash-loops on D3DMetal.
- **How a game gets it:** through a detection rule, `when exe=<exe> => hub_dll_dir=dxgi/d3dmetal`. Our ntdll
  prepends that directory after compatdb.so has chosen its backend (wine 2dbfcfc).
- **Shipping:** D3DMetal is never part of a bundle or a published runtime.

## What went wrong first (2026-10-31)
Apple's Game Porting Toolkit downloads (4.0b3, then 3.0) were installed from their evaluation "redist". That glue
is built for **Apple's** evaluation Wine. In ours:
- D3DMetal called NULL entry points;
- exceptions went to a handler at a garbage address (`0x0020019008070C10`, 269 times);
- the game hung with no window.

Swapping D3DMetal versions, removing the NVIDIA shim and disabling Streamline's Reflex changed nothing, because the
glue itself was the problem. CrossOver's own glue for the same D3DMetal works: HITMAN 3 runs and plays (owner,
2026-10-31). The lesson is in development/diary/2026-10-31-07.md: start from a known-good reference integration and
change one variable at a time.
