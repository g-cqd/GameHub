---
status: accepted
date: 2026-10-30
---

# 0008: Runtime files are replaced, never edited in place

## Context
Running Wine processes map the runtime's `.so` and `.dll` files, and the wineserver and the Steam client stay up for
hours. Writing over a mapped file in place changes the pages under a running process, and the process crashes or
behaves strangely long after the edit. The runtime files are also often APFS clones of the build output, so writing
to one could reach its clone source.

## Decision
To change one file in a runtime: `chflags nouchg` if needed, then `rm`, then `/bin/cp -c` the new build output into
place. For a PE module that DXMT or mtld3d builds, run `winebuild --builtin` on it afterwards. Never use `cp` over an
existing file, `sed -i`, or an editor on the runtime itself.

## Consequences
- Running processes keep the old file until they restart, so a report about an installed fix says which processes
  still run the old code.
- Use `/bin/cp`, not the GNU `cp` that is first in `PATH`, which has no `-c`.
