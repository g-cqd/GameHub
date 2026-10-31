---
status: accepted
date: 2026-10-11
---

# 0007: The x87 sidecar attaches cooperatively to 32-bit processes

## Context
Rosetta 2 runs x87 code at 64-bit double precision and slowly. 32-bit games that rely on 80-bit x87 behaviour
misbehave, and x87-heavy games crawl. x87sidecar (`g-cqd/x87sidecar`, from athei) translates x87 blocks itself and
hands everything else to stock Rosetta. The owner wants the sidecar "on for every 32-bit game".

## Decision
- **How it attaches:** when Wine's loader starts a 32-bit (i386 or unknown-machine) process with `compat_x87` set, it
  execs the sidecar in cooperative mode first: `x87sidecar --cooperative <loader> <args…>`. Rosetta's AOT environment
  is saved and restored around that exec.
- **What the sidecar ships with:** it is installed as `bin/x87sidecar` in the runtime, ad-hoc signed and without
  entitlements, as `assemble_runtime.sh` copies it.
- **Children:** `ROSETTA_DISABLE_AOT`, which the sidecar needs for itself, is not passed on to child processes
  (2026-10-11).
- **Where it is decided:** whether a process gets the sidecar is decided in the runtime (compatdb and rules), never by
  a wrapper.
- **Logging:** the attach is logged at TRACE since 2026-10-31. A failed `execv` is logged at WARN, and the process
  then continues on stock Rosetta.

## Consequences
- A sidecar crash takes the game with it. When cooperative setup fails, the sidecar runs the target without its hook
  (upstream, merged 2026-10-08).
- Changes to the sidecar ship to every 32-bit game at once, so they are covered by its CTest suite before they are
  installed.
