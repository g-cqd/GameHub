---
status: not-started
blocked-by: []
date: 2026-10-31
---

# 0019: Follow-ups to the DXMT staging allocator

- **Base ring:** keep one base ring, rather than growing to a new ring and later shrinking (ADR-0016).
- **Finishing thread:** it spins in `atomic::wait`. Measure its CPU time, then make it block.
- **Border colour:** the fallback is opaque white. Find the case and match D3D11.

## Done when
Each change has a unit test in `tests/unit/`, and a level load in Crysis 2 Remastered shows no new staging buffers
after warm-up (INFO log).
