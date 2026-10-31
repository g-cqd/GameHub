---
status: not-started
blocked-by: []
date: 2026-10-30
---

# 0013: Crysis 3 and Battlefield 3 on hub-2

- **Crysis 3:**
  - Performance.
  - The tessellation factor is clamped at 8.
  - The 32-bit rename budget stalls.
- **Battlefield 3:**
  - Tessellation pipeline signature mismatch.
  - The display mode is set 8 times at start.
  - DXMT profile: NaN-safe sampling, no FMA, 60 fps pacing.

## Done when
Both play on hub-2 without these, measured by frame-time logs, not by impression.
