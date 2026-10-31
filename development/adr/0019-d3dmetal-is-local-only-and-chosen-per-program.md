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
- **Where it lives:** D3DMetal goes in `lib/wine/dxgi/d3dmetal`, copied from a local GPTK by
  `assemble_runtime.sh` with `GPTK_REDIST`. `gptk` stays an alias of DXMT.
- **How a game gets it:** a program gets D3DMetal through a detection rule, `when exe=<exe> => hub_dll_dir=dxgi/d3dmetal`.
  Our ntdll prepends that directory after compatdb.so has chosen its backend (wine 2dbfcfc).
- **Shipping:** D3DMetal is never part of a bundle or a published runtime (ADR-0001's bundles, apps/bundler).

## Status of the interface
Our winemac exports the `macdrv_functions` table of CrossOver 26, which ships **D3DMetal 3.0**. With GPTK
**4.0 beta 3**, HITMAN 3 loads D3DMetal and then waits forever, before creating a window. September's records show
the same with 4.0b2 and NFS 2015. So until winemac supports the 4.0 interface, or a D3DMetal 3.0 is available
locally, the HITMAN rule stays disabled (roadmap 0030).
