---
status: not-started
blocked-by: []
date: 2026-11-01
---

# 0036: Assassin's Creed Unity runs slowly

Reported by the owner ("very slow"), with the game running at 2560x1440 borderless.

## Facts
- **Tracing.** Two earlier sessions ran with trace channels on (`+cursor`, then `trace+macdrv`, with 181,000 lines in
  minutes). The session measured below ran with `WINEDEBUG=-all`, and the owner still found it slow.
- **CPU.** During gameplay, `top` showed ACU.exe at about 1,045% CPU, about 10 of the M2 Pro's 12 cores.
- **Over 18 minutes** (wine64 process 31475):

  | Measure | Value |
  |---|---|
  | Context switches | 20,176/s |
  | BSD system calls | 45,020/s |
  | Mach system calls | 5,252/s |
  | Messages to wineserver | 2,299/s |
  | Kernel share of CPU time | 20% (5:44 of 28:24) |

- **Where the waiting is.** In a 15 s gameplay sample, the leaf frames that `sample` couldn't name sit under
  `__wine_syscall_dispatcher` → `msync_wait_objs`, `NtWaitForAlertByThreadId`, `NtSetEvent`/`signal_all`,
  `server_call_unlocked`.
- **Rosetta code** (JIT and runtime) was under 3% of leaf samples.

## Not yet known
Whether frames are limited by the CPU or the GPU. Measure with the Metal HUD (`MTL_HUD_ENABLED=1`) at the same spot,
then at a lower render size: `hub --metalfx 2.0`, or a lower in-game resolution.

## Done when
The cause is measured, and the change that removes it makes a measured difference in frame time at the same spot.
