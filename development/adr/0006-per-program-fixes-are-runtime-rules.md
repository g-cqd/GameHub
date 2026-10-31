---
status: accepted
date: 2026-10-24
---

# 0006: Per-program fixes are rules shipped with the runtime

## Context
By 2026-10-24, per-program behaviour lived in four places:
- `compat_db()` and `session_env()` in the launcher;
- the closed `compatdb.so` taken from CrossOver;
- environment variables set by wrapper scripts;
- hard-coded exe names inside Wine patches.

`docs/hub/runtime-fixes-and-detection-plan-20261024.md` inventories them. A fix in the launcher doesn't apply when a
game is started by its store client rather than by the hub.

## Decision
Wine reads `share/wine/hub-rules.txt` (from `runtime/hub-rules.txt` in the repository) at process start, before
`compatdb.so` (wine commit "ntdll: Apply runtime rules from share/wine/hub-rules.txt before compatdb.so", 2026-10-24).

- **Matching:** a rule matches a process by `exe=`, `company=` and `machine=`, or by a PE section (`section=.ubx2`).
- **Effect:** a rule sets the graphics backend, environment variables and flags, for example
  `gate_selector_fixup=true` for the Ubisoft packer's Heaven's-gate far jumps. `name=default;exe=*` sets the
  defaults.
- **Process tree:** the result is synced into the PEB and the WoW64 process parameters, so child processes see the
  same decision.

## Consequences
- **One mechanism:** a fix applies however the game is started (hub, Steam, EA, Ubisoft), and it travels with the
  runtime.
- **Migration still owed:** the remaining launcher-side `compat_db()` and `session_env()` logic is to move into
  rules (roadmap 0018).
- **When a rule is right:** a rule is the place for something only one program needs. Behaviour that every program
  needs is fixed in the fork itself (the white paper's "generic first").
