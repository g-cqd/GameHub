---
status: in-progress
blocked-by: []
date: 2026-10-31
---

# 0004: EA and Epic on hub-2, then delete hub-1

Every provider has defaulted to hub-2 since b2455c8 (ADR-0009). hub-1 is the only runtime known to run EA and Epic.

## Steps
1. Close Steam and Ubisoft, and let downloads finish. Then run `hub start ea` alone and read
   `Hub/Logs/ea-*.log` and `Prefix/drive_c/ProgramData/EA Desktop/Logs/EADesktop.log`.
   - On 2026-10-31 EA did not reach "SPA load success" in 150 s, with swap at 6 of 7 GB and four launchers open.
   - The only lead is `WSALookupServiceBegin failed with: 0` (`network_change_notifier_win.cc`).
   - EA booted in about 6 s on hub-1.
2. Run the same test for Epic, then `hub play` GTA V through it.
3. If both pass, delete `Runtimes/hub-1` and `bin/hubenv.sh`, and update the remaining mentions in the docs.

## Done when
EA boots and starts one game on hub-2, Epic does the same, and hub-1 is gone.
