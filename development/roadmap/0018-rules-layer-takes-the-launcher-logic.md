---
status: not-started
blocked-by: []
date: 2026-10-24
---

# 0018: The rules layer takes the rest of the launcher's per-program logic

The remaining `compat_db()` and `session_env()` branches in `launcher/hub` move into `runtime/hub-rules.txt`
(ADR-0006). The BOOLEAN low-byte syscall read (1e06100) gets tests in `dlls/ntdll/tests`.

## Done when
`launcher/hub` has no exe-name branches, apart from the session watchers, and the BOOLEAN tests pass on hub-2.
