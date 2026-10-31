---
status: accepted
date: 2026-10-31
---

# 0015: Static analysis is part of every fork's gate

## Context
On 2026-10-31 the owner asked for a static-only review of every project. No games were to be run, and every real
finding was to be fixed ("no we want to fix everything").

## Evidence
The checkers found real defects:
- **Wine:**
  - unchecked `realloc` and `malloc` in the environment builder and in the x87 sidecar exec;
  - `memcpy` from NULL descriptor parts;
  - `malloc(0)`;
  - an ncrypt property that lost its key on an allocation failure;
  - an uninitialised `SECTION_IMAGE_INFORMATION`.
- **DXMT:** uploads were dropped silently after a retry, and an uncaught `out_of_range`.
- **x87sidecar:** a dead and wrong ext-reg encoding, and an unchecked IR input.
- **Launcher:** a crash when the EA app is missing, and leaked file handles.

Most hits in upstream code were false positives. Examples: the 524-byte Darwin float state, the `info`
out-parameters, and switch defaults that cover every case.

## Decision
These checkers run before a change to the code they cover is pushed. They are in `scripts/static-analysis/`.

| Code | Tool |
|---|---|
| Wine | `wine_analyze.py`: the clang analyzer on the real compile commands of every file our commits touched |
| DXMT, x87sidecar | `tidy.sh`: clang-tidy analyzer and bugprone checks through each build's `compile_commands.json` |
| mtld3d | `cargo clippy` for both Windows targets and the unix workspace |
| Launcher, scripts, bundler | `python.sh`: ruff, pyright and shellcheck |

cppcheck is a second opinion for C.

**Triage rules:**
- A finding on a line we wrote is fixed or explained.
- A finding on an upstream line in a file we touch is fixed when it is real, and recorded as a false positive in the
  diary when it is not.
- Style-only checks (`PLW1510` and `bugprone-signed-bitwise`, for example) are off.

## Consequences
- Static analysis is evidence level 4 (white paper §3). It never replaces running the game.
- Homebrew clang-tidy can't parse x87sidecar's `std::atomic_ref` with Apple's libc++. Those errors are tooling noise.
