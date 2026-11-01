---
status: in-progress
blocked-by: []
date: 2026-11-01
---

# 0035: Wine in Swift (ADR-0020)

## Steps
1. **Done (2026-11-01).** `winekit/` package, the first piece (`HubRules`), and gates in Swift (`swift package quality`):
   - Aemi's configuration, manifest and tags checks;
   - swift-format and SwiftLint;
   - deadwood, dolly, arcleak, fcheck and modeler, as Aemi's lock pins them;
   - tests in debug and release;
   - Embedded Swift with libc only;
   - the differential test against Wine's C;
   - swift-mutation-testing.

   The git hooks run them scoped to the change (`.project-hooks.yml`).
2. **Done (2026-11-01). HubRules runs inside ntdll** (wine b9f9755bb12, 6e3f9b1cafd).
   - **C interface:** `winekit/C/winekit.h`, with `winekit_hub_rules_apply` and `winekit_free`.
   - **Build:** `swift package wine-objects` builds `libwinekit.a` (Embedded Swift, x86_64, no stack protector, libc
     only). `build-macos-x86_64.sh make` builds it and passes `WINEKIT_DIR`.
   - **What stays C:** `hubrules.c` keeps the rules file, the executable's bytes (a pread callback), the environment,
     the PEB and the image fix-up. Its rules logic is gone (-284 lines).
   - **Checked:**
     - The C as it was (`Differential/reference/hubrules.c`) and the new file with `libwinekit.a` print the same
       stdout and stderr in 312 cases, including warnings in rule order and `debugstr_a`'s truncation quirk.
     - Live: Ubisoft Connect matched line 34 in `upc.exe` and `UplayService.exe`, and rewrote its 10 far jumps.
       compatdb.so chose the same rules and backends as with the old ntdll.
   - **Installed** in hub-2, with the previous `ntdll.so` kept as `build/ntdll.so.before-winekit`.
   - **Not yet run:** Steam, HITMAN 3 (`hub_dll_dir`) and Far Cry 3 with the new ntdll; their executables are in the
     differential corpus.
3. **Spike: Embedded Swift for Windows targets.** Build its standard library for i686 and x86_64 Windows, and link one
   PE function into a Wine DLL. Done when it runs in a game process, or when it is shown it can't.
4. **The next Unix-side piece, chosen by measurement.** The candidates are where roadmap 0036 found the cost: msync
   waits and wakes, and the wineserver request path. Each piece needs a benchmark against the C in the same process
   before it replaces anything.

## Not decided
- **Trust:** the hooks need `git config project-hooks.trusted true` in GameHub, the owner's call.
