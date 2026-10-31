---
status: accepted
date: 2026-10-31
---

# 0012: Ubisoft Connect renders in software

## Context
On 2026-10-24 Ubisoft Connect was started through `upc.exe` with `--in-process-gpu`, which rendered on hub-1. On
hub-2, its in-process GPU drawing through DXMT glitched (c8b577d). The Ubisoft overlay's hook also spun on the overlay
mutex before the game's D3D device existed, and it froze Watch_Dogs whenever another game had started first
(d7f20b8).

## Decision
- Ubisoft Connect runs with `--disable-gpu`, set in the runtime rules.
- The Ubisoft overlay is kept out of game processes.

## Consequences
The client UI is drawn in software, which is slower but correct. Revisit this when DXMT's handling of Chromium's GPU
process is fixed, with a screenshot comparison as the evidence.
