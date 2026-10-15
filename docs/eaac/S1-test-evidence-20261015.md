# S1 Test Evidence — 15 October 2026

**Date:** 15 October 2026
**Evidence for applying S1.1/S1.2 from `docs/eaac/S1-prefix-isolation.md`**

---

## Clone test (never touched the real Prefix)

**Pre-flight:** no wine/EA/game process was running before the test started.

**Clone creation:** an APFS clone of the real Prefix was made to `/Volumes/ExT2/GameHub/work/s1-test/prefix-clone` via `cp -c -R`, then `chmod 0700`. The real Prefix was confirmed unchanged before and after (`ls -ld` identical).

**S1.1 on the clone only:** verify PASS on all 3 checks — `z-empty` directory exists, `dosdevices/z:` resolves to it, permission bits are 500.

**S1.2 on the real runtime (deliberate, not the clone):** applied directly to the real runtime rather than the clone, because `chflags` is instantly reversible, touches no Prefix/game-state data, and is the only way the `E:\Runtimes` negative test is meaningful (since `e:` is unchanged in both clone and real setups). Verify PASS on all 8 checks: `uchg` present on `bin/wine`, `ntdll.so`, `ntdll.dll`, `x87sidecar`, and the canary file; attempted overwrite of the canary blocked with size unchanged; new-file creation inside `$RT/bin` blocked.

**Launch tests against clone prefix + real (now-protected) runtime:**

- EA Desktop: full process tree came up cleanly (`EADesktop.exe`, `wineserver`, `winedevice.exe` x2, `x87sidecar`, `EACefSubProcess.exe` helpers). The internal `EADesktop.log` showed:
  > "SPA load success, url:[https://pc.ea.com/en]"
  with HTTP status 200 — the authenticated app UI loaded. No fatal exceptions.
- Need for Speed (2015, `NFS16.exe`): launched directly via the same wine binary/env against the clone prefix. The process (plus `ActivationUI.exe`/`EALauncher.exe` helpers) stayed alive at ~59s, confirmed via `ps`, and was terminated cleanly with a single `kill` (SIGTERM).

**Negative tests — 5 of 5 PASS:**

1. `wine cmd /c dir Z:\` → `"File not found."` (empty `z-empty` dir, not `/Volumes` contents)
2. `wine cmd /c dir Z:\Users` → `"File not found."` (no escape to `/Users/gc`)
3. `wine cmd /c dir C:\..` → resolves inside the clone's own `C:\` root, not `/Users/gc`
4. Write attempt to `E:\Runtimes\hub-0-winemacfs-dxmtrtv-noWineVer\bin\s1-negative-test.txt` → `"Path not found."`; confirmed on the host side that no file was created in the real runtime
5. `wine cmd /c dir "E:\EA Games"` → listed Battlefield 3, Battlefield 4, Crysis 3, F1 24, Need for Speed

**Real Prefix integrity:** `ls -ld` identical before and after the entire clone-test session (unchanged mtime/size).

---

## Real apply

Performed only after the clone test above was fully green.

**Pre-flight:** no wine/EA/game process was running. A documented no-op `wineserver -k` run was performed per procedure.

**Backup recorded before change:** the dosdevices mapping was recorded manually before the change: `c:` → `../drive_c`, `e:` → `/Volumes/ExT2/GameHub`, `z:` → `/Volumes`.

**S1.1 apply+verify PASS** against the real Prefix. Final-state rollback file: `Prefix/.s1-rollback/z-target-20261015-025834.txt`. `z:` now points to `/Volumes/ExT2/GameHub/Prefix/z-empty`, mode 500.

**EA Desktop relaunch** via the real `/Users/gc/Developer/GameHub/bin/start-ea.sh`, exactly as the user would. Process tree stable at 60s. Launcher log clean (only benign Chromium/WebAuthn noise). Internal `EADesktop.log`: login telemetry status "success" type "rtm", four "SPA load success" events for `https://pc.ea.com/en`, `client.boot.ready` with KPI timings, zero unhandled-exception/fatal/crash lines. `nucleusId` self-redacted by EA Desktop as `####`.

**Negative tests re-run against the real prefix** — same 5 as above, all PASS, same results as the clone test (`Z:\` empty, `Z:\Users` not found, `C:\..` stays inside `C:\` root, write to `E:\Runtimes\...\bin\` blocked with no file created on host, `E:\EA Games` readable and listing all 5 titles).

**Independent re-verification** by the orchestrating process, separate from the apply agent's own report:
- `readlink dosdevices/z:` → `/Volumes/ExT2/GameHub/Prefix/z-empty`
- `stat -f '%Sp'` on `z-empty` → `dr-x------` (500)
- `stat -f '%Sf'` on `$RT/bin/wine` → `uchg`
- no wine/EA process running
- real Prefix `dosdevices` directory listing confirmed exactly 3 entries (`c:`, `e:`, `z:`) with correct targets
- git working tree clean aside from the expected doc changes, no stray commits

**Known mid-task event (noted for completeness, not a technical failure):** during the apply agent's first EA Desktop relaunch, EA Desktop auto-triggered a game quick-launch of `NFS16.exe` on its own. The apply agent paused, rolled back S1.1 once out of caution, then re-applied it from scratch after determining the auto-launch behavior was unrelated to S1.1/S1.2. The final, re-applied state documented above was independently re-verified and is correct.

A separate, pre-existing, out-of-scope issue was also noted during this session: some games show a stale login dialog on launch instead of reusing the EA Desktop session. This is unrelated to S1, was not fixed here, and is flagged as a follow-up for a different task.

---

## Final state

- **S1.1:** APPLIED to the real Prefix. `z:` → `Prefix/z-empty` (mode 500). `c:`/`e:` unchanged.
- **S1.2:** APPLIED to the real runtime. `uchg` on `$RT/bin`, `$RT/lib`, and the helpers directory.
- **S1.3:** NOT APPLIED. Still draft, needs user approval (unchanged).
- **S3:** untouched, still DEFERRED (unchanged).
- All wine/EA test processes were stopped cleanly afterward (`wineserver -k`); system left idle.
- The clone prefix at `/Volumes/ExT2/GameHub/work/s1-test/prefix-clone` is to be deleted after this evidence is committed (separate follow-up step, not part of this document).
