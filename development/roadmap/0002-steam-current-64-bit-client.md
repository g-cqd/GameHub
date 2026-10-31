---
status: done
blocked-by: []
date: 2026-10-31
---

# 0002: Steam on the current 64-bit client

Replace the blocked 32-bit client with the current one (ADR-0010).

## Done when
The client renders, signs in and updates itself on hub-2. The hub starts it without the anti-update flags.

## Result (2026-10-31)
Done in 307536d and d707b0a. The 32-bit client is kept in `Library/Steam-legacy`. Launching a game through the new
client is roadmap 0006.
