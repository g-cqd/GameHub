---
status: accepted
date: 2026-10-24
---

# 0005: Graphics backends live in their own directories and are picked per process

## Context
Some processes need DXMT, others wined3d, and D3D9 can be served by mtld3d or wined3d:
- the Chromium-based clients (Steam's webhelper, the EA app, Epic, Ubisoft) render badly on some backends;
- some games crash on one backend and work on another.

Swapping DLLs in `lib/wine/x86_64-windows` per game is a manual edit of a shared runtime.

## Decision
`assemble_runtime.sh` installs each backend into its own directory, with Wine fake modules left in the standard
location:

| Directory | What it holds |
|---|---|
| `lib/wine/dxgi/dxmt/<arch>-windows/` | DXMT's dxgi, d3d11, d3d10core and winemetal (and `x86_64-unix/winemetal.so`) |
| `lib/wine/dxgi/wined3d/<arch>-windows/` | Wine's dxgi and d3d10/11 |
| `lib/wine/d3d9/mtld3d/` | mtld3d |
| `lib/wine/d3d9/wined3d/` | Wine's d3d9 |

The backend is chosen per process by a rule (`dxgi=`, `d3d9=`; ADR-0006) or by `--dxgi`. The defaults are mtld3d
for D3D8/9 and DXMT for D3D10/11, and the clients' web helpers use wined3d.

## Consequences
- Two backends can serve two processes of the same session.
- A rebuilt backend is installed into its own directory only (rm then cp; ADR-0008), then re-marked with
  `winebuild --builtin`.
