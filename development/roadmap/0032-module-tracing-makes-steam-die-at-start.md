---
status: not-started
blocked-by: []
date: 2026-10-31
---

# 0032: `+module` tracing makes Steam die at start

Observed twice on 2026-10-31: `WINEDEBUG=err+all,warn+module,trace+module` (logs `steam-20261031-234935.log` and
`steam-20261031-235228.log`). `steam.exe`'s main thread (0024) logs:

    err:seh:call_seh_handlers invalid frame 00000001000FF138 (0000000000012000-0000000000110000)
    err:seh:NtRaiseException Exception frame is not in stack limits => unable to dispatch exception.

Then Steam exits. With the same runtime and the normal flags, Steam starts (23:55). The exception frame lies just
above the stack's top limit (0x110000), so tracing likely pushes a deep start-up path past the stack.

## Done when
Steam starts with `+module` tracing, or the limit is understood and documented with a working alternative.
