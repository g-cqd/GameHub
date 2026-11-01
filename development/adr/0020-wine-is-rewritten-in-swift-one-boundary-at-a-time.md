---
status: accepted
date: 2026-11-01
---

# 0020: Wine is rewritten in Swift, one boundary at a time

## Context
The owner wants Wine rewritten for safety and speed, with modern data structures, and asked whether Rust or Swift fits.
Swift brings the owner's tools: arcleak, dolly, deadwood, modeler, fcheck, swift-mutation-testing, SwiftLint and
swift-format, plus the shared Aemi tooling.

Facts measured on 2026-11-01:
- **Size.** Wine is about 6.0 million lines of C in 726 DLLs.
  - About 41 DLLs have a Unix side (`.so`).
  - The wineserver is a separate process: 60,000 lines speaking 306 requests (`server/protocol.def`).
  - ntdll's Unix side is 61,000 lines, win32u 82,000 and winemac 26,000.
- **Swift on the Unix side.** Embedded Swift compiles for `x86_64-apple-macos15`, the code Wine's Unix side runs,
  with **no Swift runtime**. The object needs only libc symbols (`bzero`, `free`, `posix_memalign` and the stack
  guard). A C caller linked and ran it. Standard Swift works too but links the Swift runtime libraries.
- **Swift on the PE side.** The Swift 6.4.2 toolchain ships Embedded Swift's standard library for Apple and some
  embedded targets, and none for Windows. Swift can't build Wine's PE DLLs until that standard library is built for
  i686 and x86_64 Windows.
- **Rust.** `no_std` Rust builds for x86_64 macOS, x86_64 Windows and i686 Windows today.
- **Where the cost is.** In Assassin's Creed Unity, Wine's Unix side carried ~20,000 context switches/s and ~2,300
  wineserver requests/s, and 20% of the game's CPU time was in the kernel (see roadmap 0036). That is where a rewrite
  can gain the most.

## Decision
- **Language:** Swift. Library code is written so that it compiles as Embedded Swift: no Foundation, no existentials,
  byte-level text, generics instead of `any`. The same source then links into Wine's Unix side with no runtime. Host
  tools may use Foundation.
- **Method:** the strangler pattern. One piece at a time, behind a boundary Wine already has: a Unix library entry
  point, the wineserver protocol, or a driver interface. Each new piece must:
  1. produce **byte-identical** results to the C it replaces, over a corpus of real inputs (a differential test);
  2. pass every gate: Aemi's configuration and manifest checks, the five analyzers, tests in debug and release,
     Embedded Swift with libc only, and mutation testing with a score of at least 90;
  3. replace the C only after that, in a commit of its own.
- **The Windows side** stays C until roadmap 0035's spike shows Embedded Swift working for Windows targets.
- **The package** is `winekit/` in this repository, until it gets a repository of its own.

## The first piece
`HubRules` ports `dlls/ntdll/unix/hubrules.c`: rules parsing, predicate matching and reading facts from the PE
headers. Results:
- **Differential test:** identical to Wine's own `hubrules.c` in 312 cases. They cover real 32- and 64-bit game
  executables, malformed PE files, and edge-case rules. The comparison also confirmed some C quirks the port keeps on
  purpose, such as `when ;; ; =>` matching every program.
- **Embedded build:** a 52 KB object needing libc only.
- **Not yet done:** linking it into ntdll in place of the C. That is roadmap 0035, step 2.

## Consequences
- **Gates:** they live in Swift (`QualityKit`, `swift package quality …`), with no shell scripts, and are tested with
  fakes for processes and the file system. The hooks run them scoped to what a commit or push changes.
- **Speed is unproven.** Any speed claim needs a benchmark of the Swift piece against the C piece in the same
  process.
