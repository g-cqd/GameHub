---
status: not-started
blocked-by: []
date: 2026-10-31
---

# 0025: x87sidecar allocation and performance

Translation buffers come from verified native allocators, and the assembler's storage growth is bounded
(2026-09-26). The remaining work is in the sidecar's own roadmap and benchmarks (`benchmarks/`).

## Done when
The next change measures before and after on the same benchmark (white paper §3), and it ships to hub-2 only with
its CTest suite green.
