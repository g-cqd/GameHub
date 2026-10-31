---
status: accepted
date: 2026-10-31
---

# 0016: DXMT staging memory is a ring, an arena and a pool, and uploads are submitted by budget

## Context
DXMT's staging allocator handed out one-off blocks held in a FIFO until the GPU finished with them. While a level
loads, games create hundreds of textures with initial data and draw nothing. Every upload then waited for the same
submission, and none of the staging memory could be reused. Crysis 2 Remastered allocated 181 blocks of 64 MB
(11 GB) and swapped the Mac.

## Decision
These are in `src/dxmt/dxmt_ring_bump_state.hpp`, which is unit-tested natively with `tests/unit/run.sh`.

**Staging memory has three tiers:**

| Tier | Requests | Grows | Shrinks |
|---|---|---|---|
| Ring | up to the block size | A full ring is replaced by one twice its size; the old one is released after the newest chunk that used it. | Replaced by a smaller ring after `kStagingBlockLifetime` chunks under a quarter full; released when idle. |
| Arena | larger ones | Created on the first large request, `kLargeArenaBlocks` × block size (256 MB). | Released when idle. |
| Pool | ones the arena can't take | Power-of-two classes, reused after the GPU is done. | Capped at `kLargePoolCapBlocks` × block size (512 MB) and trimmed when idle. |

**Uploads are submitted by budget:** the resource initializer submits its queued uploads once 128 MB is pending
(`kUploadFlushBytes`), and retries an allocation once after a flush. Since d907082, an initialization still
dropped after that retry is logged at ERR, and each new staging buffer is logged at INFO.

## Consequences
- Staging memory is bounded and reused during level loads.
- Open follow-ups:
  - **Base ring:** keep one ring instead of growing and dropping rings.
  - **Finishing thread:** it spins in `atomic::wait`.
  - **Flashing in Watch_Dogs:** this has been shown not to be the allocator (roadmap 0019).
- DXMT commits stay on the fork (ADR-0003).
