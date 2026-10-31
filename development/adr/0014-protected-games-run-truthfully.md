---
status: accepted
date: 2026-10-15
---

# 0014: Protected games run on Wine truthfully, never by evasion

## Context
EA anti-cheat (EAAC, for F1 24, BF2042 and others) and Ubisoft's packers check the Windows environment. One session
proposed hiding Wine and evading detection. The owner, verbatim: "we don't want to evade anticheat detection, we just
want it to run on wine, so please go towards that path". The owner also asked whether `eaanticheat.sys` is really
needed: "is that a guess, an assumption?"

## Decision
- **Allowed:** for compatibility, Wine provides what Windows provides:
  - raw syscalls with the Windows 10 19045 numbering;
  - the `Zw` stubs as the anti-cheat loader expects them;
  - the native `\SystemRoot` path expansion;
  - the CatRoot directories.
- **Not allowed:** no identity is forged and nothing is hidden from detection. A claim that a component is required
  (a driver, a service) is probed before work starts on it (white paper §0).
- **Scope:** reverse-engineering for compatibility is in scope, as documented in every fork's
  `REVERSE-ENGINEERING.md` (2026-10-15).

## Consequences
- **EAAC:** F1 24 is still blocked (E111000D, syscall gate). It is a long-term item (roadmap 0022,
  `docs/eaac/EAAC-IMPLEMENTATION-ROADMAP.md`).
- **Other games:** the same rule covers Ubisoft's Heaven's-gate far jumps (a selector fixup the rules switch on) and
  ARPL in x87sidecar.
