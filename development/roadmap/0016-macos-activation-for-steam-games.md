---
status: not-started
blocked-by: []
date: 2026-10-31
---

# 0016: Games started by Steam become the active macOS app

A game launched by the Steam client doesn't get macOS activation, so input and focus stay with the previous app. A
handoff helper is proven in `/tmp/kusd/handoff.swift`. Move it into the repository first: `/tmp` is not kept.

## Done when
The helper, or the same logic in winemac, is part of the runtime or the hub, and a game started from the Steam UI is
frontmost with keyboard focus.
