---
status: in-progress
blocked-by: []
date: 2026-10-25
---

# 0012: GTA V graphics under DXMT

`docs/hub/gtav-graphics.md` has the whole investigation.

## Open problems
- DX11 `itrproj` failure.
- Crash at MSAA 8x.
- Texture streaming and swaps. These were shown to come from memory pressure, so `hub trim epic` exists.
- Magenta and white lattices. MSAA off removes them. The three light-volume shaders are not the cause.

## Settled
- `d3d11.preciseDivide` and FMA off remove the pipeline-state failures.
- `strictMath` did not help.
- The video-memory cap stays off.

## Done when
The game plays at the owner's settings with MSAA on and no lattices, or the remaining DXMT defect has its own item
with a reduced reproducer.
