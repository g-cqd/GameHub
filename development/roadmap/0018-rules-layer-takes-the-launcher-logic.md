---
status: in-progress
blocked-by: []
date: 2026-10-24
---

# 0018: The rules layer takes the rest of the launcher's per-program logic

The remaining `compat_db()` and `session_env()` branches in `launcher/hub` move into `runtime/hub-rules.txt`
(ADR-0006). The BOOLEAN low-byte syscall read (1e06100) gets tests in `dlls/ntdll/tests`.

## Done when
`launcher/hub` has no exe-name branches, apart from the session watchers, and the BOOLEAN tests pass on hub-2.

## Progress (2026-11-01)
The launcher's static per-exe rules were duplicates of `runtime/hub-rules.txt` lines 11–14 (Steam web helper, EA
CEF and GEP, Epic web helper) and are removed. What remains in `compat_db()` and `session_env()` depends on launcher
state:
- `--dxgi` for Act of Aggression;
- `--metalfx` and the per-game settings files (`game_env`);
- session-wide environment for one store (EA's trap-flag emulation, Epic's mscoree).

A per-exe rule can't express the last group, so they stay by design.

Still owed: the BOOLEAN low-byte syscall tests in `dlls/ntdll/tests`.

