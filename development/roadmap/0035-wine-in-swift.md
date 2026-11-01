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
2. **Link HubRules into ntdll.** Wine's build compiles `winekit/Sources/HubRules` as Embedded Swift for x86_64 and
   links it into `ntdll.so`. A C shim keeps the side effects in C: environment, PEB, patching the image. Done when
   Steam, HITMAN 3 and Far Cry 3 start with the same `WINE_COMPATDB` as with the C, and the C file is gone.
3. **Spike: Embedded Swift for Windows targets.** Build its standard library for i686 and x86_64 Windows, and link one
   PE function into a Wine DLL. Done when it runs in a game process, or when it is shown it can't.
4. **The next Unix-side piece, chosen by measurement.** The candidates are where roadmap 0036 found the cost: msync
   waits and wakes, and the wineserver request path. Each piece needs a benchmark against the C in the same process
   before it replaces anything.

## Not decided
- **Repository:** whether `winekit/` gets its own repository, and its name and visibility (the owner's call).
- **Trust:** the hooks need `git config project-hooks.trusted true` in GameHub, the owner's call.
