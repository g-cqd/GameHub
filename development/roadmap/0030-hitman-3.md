---
status: in-progress
blocked-by: []
date: 2026-10-31
---

# 0030: HITMAN 3 (World of Assassination)

HITMAN 3 is D3D12-only. It has been launched through `hub play hitman` on hub-2; it doesn't reach a window yet.

## What happened on 2026-10-31
- **Wine's own d3d12** (vkd3d over MoltenVK), next to DXMT's dxgi: the D3D12 device was NULL, and the game crashed
  in `CheckFeatureSupport`. With the matching wined3d dxgi, the device exists, but the game aborts at the
  pipeline-library check.
- **DXMT's d3d12**, enabled in our build (`-Denable_d3d12=true`, now in `dxgi/dxmt` and in `assemble_runtime.sh`),
  needed these fixes, all in DXMT b2d3a28, 155a850 and e0f8ca4:
  - pipeline libraries (the game requires `D3D12_SHADER_CACHE_SUPPORT_LIBRARY`);
  - answers for OPTIONS5 and later instead of failures;
  - shader-model and root-signature requests lowered instead of refused;
  - PIX markers that no longer abort;
  - DXIL `discard` in mid-block.

  Now blocked on **DXIL wave operations** (`dx.op.waveActiveOp`, `dx.op.waveAllOp`), which DXMT's converter lacks,
  and on one untranslated value. The game then hits its own assertion.
- **Apple D3DMetal** (GPTK 4.0b3, ADR-0019): loads, then the game waits forever with no window. This is most
  likely the D3DMetal 4.0 interface against our winemac's CrossOver 26 (3.0) table.

## Running (2026-10-31, 23:57)
HITMAN 3 runs and plays on hub-2 with D3DMetal 4.0b2, installed as CrossOver ships it (ADR-0019), through the rule
`when exe=HITMAN3.exe => hub_dll_dir=dxgi/d3dmetal`. The owner: "it's working rather good". Not yet measured:
frame rate, a whole mission, saving and loading.

## Next
- Play a mission, then note frame rate and any graphical issue here.
- The DXMT D3D12 path stays useful for every D3D12 game without D3DMetal. Its next gap is DXIL wave operations.

## Done when
HITMAN 3 reaches its main menu and plays a mission.
