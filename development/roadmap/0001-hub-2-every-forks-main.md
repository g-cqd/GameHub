---
status: done
blocked-by: []
date: 2026-10-30
---

# 0001: Runtime hub-2, assembled from every fork's main

Rebuild the runtime from scratch from the `main` of every fork after the upstream sync (ADR-0003), with the same file
set as hub-1.

## Done when
hub-2 is assembled by `scripts/assemble_runtime.sh`, `install_mtld3d.sh` and `bundle_media.py`, with no file missing
against hub-1. It passes a smoke test in a scratch prefix, with 64-bit and 32-bit `cmd`.

## Result (2026-10-30)
Done. The fork hashes are in `docs/hub/upstream-sync-20261030.md`:

| Fork | `main` at |
|---|---|
| Wine | 7819dea |
| DXMT | ae22950 |
| mtld3d | 6f119dc |
| x87sidecar | dbda79a |

The file list matches hub-1 (1,953 files). Crysis 2 Remastered and Battlefield 3 have run on it since. Build lessons:
configure Wine only through `build-macos-x86_64.sh`, and keep the DXMT cross files in `toolchains/dxmt-cross/`.
