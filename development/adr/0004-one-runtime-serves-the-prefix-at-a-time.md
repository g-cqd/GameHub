---
status: accepted
date: 2026-10-24
---

# 0004: One runtime serves the prefix at a time

## Context
Different Wine builds speak different wineserver protocol versions. When a process from runtime A joins a prefix
whose wineserver came from runtime B, it fails with a version mismatch. In October, EA ran on one runtime and Steam
on another.

## Decision
The launcher keeps the prefix on one runtime. Starting a store or game that needs a different runtime stops what is
running, which it refuses to do while a game runs unless `--restart` is given. Then it starts the wineserver of the
new runtime. The runtime is chosen by `--runtime`, then `HUB_RUNTIME`, then `PROVIDER_RUNTIME`. The launcher also
refuses concurrent launcher sessions (2026-10-24).

## Consequences
- Switching between stores that default to different runtimes costs a full prefix restart. This is one reason for a
  single unified runtime (ADR-0009).
- `hub status` reports the runtime that is serving the prefix.
