# F1 24 with EA anticheat on macOS: current engineering handoff

> Wine source: now at /Users/gc/Developer/wine (moved 2026-10-15), branch `main`. Former `/Volumes/ExT2/GameHub/src/wine` paths in this document are rewritten to that location; `eaac-ntdll-20261014` and `development` mentions are 14 Oct history.

**Updated 14 October 2026 (afternoon session).** This consolidates the known state for a developer resuming the work. The sections below the update block describe the morning state and are kept for provenance; the block directly underneath supersedes them where they conflict. The earlier, uncorrected report is preserved at `/Users/gc/Desktop/EAAC-handoff-report.original-20261014-1033.md`; the compact corrected report is `/Users/gc/Desktop/EAAC-handoff-report.md`.

## Afternoon update (14 October 2026)

The morning handoff was already stale when this session started: job 473 **had been deployed** (SHA-256 `313e87df…`, at 12:05 local) and a controlled launch **had been run** (`run-473-20261014-102650`, 10:26Z–10:51Z, i.e. 12:26–12:51 local), producing two new artifacts: the visible error dialog text — "The program encountered E111000D at 0026FA30 during initialization. Conflicting software detected!" (WINDOW_REPORT.txt transcribes it as "E1110 00D"; the space is a transcription artifact) — and jobs 474/475 built (475 was deployed later in this session, 11:59Z). This session continued from there:

| Item | Verified state |
|---|---|
| Job 475 tests | Focused syscall: 342 checks, 0 failures, 257 stubs. Full ntdll module real run: `virtual` 2,335/104 TODO/0 fail/1 skip (job 472 profile). A/B with archived job 469 `ntdll.so` reproduces identical `change`/`info`/`om` failure counts → pre-existing baseline, no regressions. |
| Deployed runtime | Job 475 `ntdll.so` SHA-256 `fb185cd9…`, deployed atomically 11:59Z over job 473 (`313e87df…`), hashes verified both sides. |
| Run-475 | One controlled authenticated EA Desktop launch, identical procedure and narrow WINEDEBUG profile to run-473. Trigger 11:59:31Z, accepted 12:01:35Z, both launcher instances patched 257 stubs, self-terminated ~1 s later. EA Desktop: session 1 second, exit `0xE111000D`. `F1_24.exe` not created. Evidence: `run-475-20261014-135917/REPORT.txt`. |
| New diagnostics captured | `patched NtTerminateProcess via int 0x2e at 0x6fffffd75725: handle -1 exit_code e111000d caller_return 0x6fffe4ed2316 caller_read 1` — both instances, identical caller. Zero translation failures in the whole log. |
| Launcher profile before death | Deterministic per instance: `NtProtectVirtualMemory` ×1,572, `NtCallbackReturn` ×395, `NtOpenFile` ×14, `NtQueryValueKey` ×10, `NtCreateSection` ×12, `NtMapViewOfSection` ×10, `NtQuerySection` ×8, `NtOpenSection` ×8, `NtClose` ×17, `NtQueryAttributesFile` ×2, `NtCreateFile` ×2, `NtOpenKeyEx` ×3, `NtAddAtom` ×4, `NtFsControlFile` ×4, `NtAllocateVirtualMemory` ×4, others small; **no** `NtQuerySystemInformation`/`NtQueryInformationProcess`; no SCM contact. |
| Attribution note | Dialog-vs-instant-exit variation predates job 475 (run-473's own EA Desktop log has `sdur:1` instant exit at 09:42Z before job 473 deployment). The `E111000D` verdict is deterministic; terminal presentation varies independently. PunkBuster parity held (session auto-start `PnkBstrA` ran in both runs; two stale orphan `PnkBstrA.exe` from older sessions were killed before run-475). |
| Ranked hypotheses | H1: file/registry existence probes fail on prefix expectations — missing `system32\drivers\eaanticheat.sys` (confirmed absent from the whole GameHub volume; service entry exists in registry, `Start=3`) is the leading candidate. Test via job 476: trace `OBJECT_ATTRIBUTES->ObjectName` for `NtQueryAttributesFile` (RCX), `NtOpenFile`/`NtCreateFile`/`NtOpenKeyEx` (R8) in the patched-stub path with `virtual_uninterrupted_read_memory`, rate-limited. H2: memory-integrity walk reads non-canonical bytes outside the patched stubs (needs live-dump study). H3: PunkBuster flag (single-variable `Start=4` test, only after H1). |
| Open question | The terminating module at `0x6fffe4ed0000` is not identified. The gate fault at `+0x3cf0` matches `preloader_s.dll`'s read-only `.rdata` entry stub (RVA `0x3c80`), but `+0x2316` misaligns with its on-disk `.text`; the launcher EXE is packed and decrypts at runtime, so on-disk disassembly is meaningless. |

The completion criteria below are unchanged and still unmet. The raw-syscall emulation layer was shown to work for the observed calls, with zero logged translation failures (the launcher's own `int 0x2e` termination executed and produced the exact observed exit code), which is consistent with, but does not prove, a failure in the launcher's local init checks.

See "Known anti-cheat-evasion techniques already in the tree" below.

## Risks / Terms of Service (D5)

EA's anti-cheat explicitly disallows Wine/Proton and similar environments. Presenting spoofed identity to its checks risks action against the real EA account used for every test launch — up to ban. Sensitive material in logs/dumps (session tokens, signed cloudsync URLs) compounds this. Any further anti-cheat-facing experiments should use a throwaway account, and no shared artifact should ever be published without redaction. There is no claim of EA approval anywhere in this project, and none should be inferred.

## Late-afternoon addendum (second session)

- Test suite reconciled: 352 checks, 0 failures, 2 `todo_wine` (C4 gap tracked, not implemented per the no-evasion scope).
- D4 done (14 Oct; wine is now on `main`, moved to /Users/gc/Developer/wine 2026-10-15): branch `eaac-ntdll-20261014` (commit `a8187c8c3c9`) and tag `eaac-job475-fb185cd9` pushed to origin (`github.com:g-cqd/wine`).
- `eaanticheat.sys` CDN acquisition investigated to a definitive dead end — see `/Users/gc/eaac-archive/eaanticheat-cdn-20261014/REPORT-CDN-INVESTIGATION.txt`. The driver must come from a real Windows machine (Pathway A). The genuine CDN installer now sits at `C:\Program Files\EA\AC\EAAntiCheat.Installer.exe` (previous copy archived).

## Morning state (as previously documented; superseded by the Afternoon update where they conflict)

The user's objective is **full, playable F1 24 through EA Desktop on macOS with the genuine anticheat service and required protection active**. That objective is **not achieved**. The last observed EA Desktop launches returned `E111000D`; no `F1_24.exe` process was observed. No evidence establishes full anticheat service/driver activation or playable game operation. There is no measured gameplay performance and no claim of EA approval.

## Current working state

| Layer | Verified state |
|---|---|
| Source | Wine fork, now on branch `main` at /Users/gc/Developer/wine (moved 2026-10-15); 14 Oct snapshot: branch `eaac-ntdll-20261014` at HEAD `e8d83a5d09d` (job 476 work committed on top of `a8187c8c3c9`; tag `eaac-job476-92a07523`; pushed to origin). Tree clean except untracked `.cache/`. |
| CFI | The assembly enumeration helper's missing unwind metadata was fixed. Job 460 confirmed CFA = RSP + 80 at callback sites. |
| Syscall mapping | `NtAccessCheck` at Wine ID zero is now represented without confusing zero with “unmapped”: BOOL/out result plus cache ID + 1 across all three routes. |
| Test red phase | Job 468: 338 checks, 6 expected failures before the mapping correction. |
| Previously tested deployment | Job 475: SHA-256 `fb185cd96f6eee08345b37131f7e2f6864f25c5e83b9af2f4c763172fd5366a0`. Tested by focused syscall suite (352 checks, 2 marked todo). Replaced by job 476. |
| Currently deployed runtime | Job 476: SHA-256 `92a0752306fc61a2e21b194f9125d60d92d71b6af5f3dd1aaf5c2e76190858a1` at `/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer/lib/wine/x86_64-unix/ntdll.so` (deployed atomically via rename(2)). Tested: 352 checks, 0 failures, 0 todo, 0 flaky. Resolves C1/M2 publication race, C4 NtInitializeRegistry status, C5 Rosetta MXCSR on int 0x2e, and C3 mprotect error escalation. |
| Previously deployed (superseded) | Job 473: SHA-256 `313e87df166d8fb6a9c5e8acc1eca6f3662ea20821dee0318d331c4f73ddac77` (archive `ntdll-job473-313e87df.so`), live run `/Users/gc/eaac-archive/codex-20261014/run-473-20261014-102650/`; replaced by job 475 at 11:59Z. No test suite was ever run against job 473. |
| Other archived builds, not deployed | Job 474: two unexplained same-size binaries (`7ba3f198…`, `8274b3db…`); no tests, no live run. Job 469 (`d585a642…`): tested by jobs 471/472, not deployed now. |
| Live EA Desktop run on job 473 | Run `/Users/gc/eaac-archive/codex-20261014/run-473-20261014-102650/REPORT.txt`: trigger via origin2://game/launch/?offerIds=16425782 at 2026-10-14T10:32:15Z; EAAntiCheat.GameServiceLauncher.exe processes (pids 67014, 70273) showed modal Wine dialog “The program encountered E111000D at 0026FA30 during initialization. Conflicting software detected!” (screenshots in WINDOW_REPORT.txt); dialog remained open ~16–18 minutes before capture ended; F1_24.exe never started. License file missing (run-473 REPORT.txt line 38). A later live run on job 475 exists (run-475-20261014-135917, see the Afternoon update). |
| Game outcome | Last live result remains `E111000D` (modal gate-failure dialog). F1 24 is not running from this flow, and anticheat readiness remains unverified. |

The actionable resume point is job 476 argument tracing (see Next evidence). Job 475 is deployed and tested; run-475 ended E111000D with no F1_24.exe. Before any further deployment record binary hash, source state, EA Desktop version, environment, process/SCM timeline and error. `dlls/ntdll/tests/syscall.c` was edited (14:16 local) after the job 475 patch was archived and is committed in `a8187c8c3c9`; the 342-check result applies to the archived version, and the committed suite is 352 checks (0 failures, 2 `todo_wine`).

## Completion criteria

The work is complete only with direct evidence for all of these: EA Desktop chooses F1 24; the anticheat launcher completes its role; the genuine service reports healthy SCM state; required driver or protection functionality is demonstrably active on macOS; `F1_24.exe` is created and remains playable; protection remains active throughout; several comparable runs succeed; and measured frame pacing/resource use meets an explicit target. The current focused tests establish narrower Windows interface behavior. They do not satisfy any game or protection readiness criterion by themselves.

## Runtime architecture and boundaries

```text
M2 Pro / macOS
  └─ Rosetta 2: x86_64 Wine + Windows processes
       ├─ GameHub Wine runtime and wineserver
       │    ├─ ntdll Windows-number cache, Zw cells, SIGSYS/int 0x2e handling
       │    └─ x87sidecar via ROSETTA_X87_PATH
       ├─ DXMT / mtld3d / EA-specific wined3d profiles
       └─ EA Desktop
            └─ EAAntiCheat.GameServiceLauncher.exe
                 ├─ protected module and raw syscall probes
                 ├─ EAAntiCheatService request (historical run)
                 └─ F1_24.exe (not observed in current runs)
```

The user's Rust/assembly/Swift preference led to a partial **x86_64 assembly** conversion for the exact Zw cell writer, invalid registry argument validator, patch enumeration, and address membership. The signal handler, Mach VM inspection, `mprotect`, Wine PE/cache lookup, and syscall frame integration remain thin C glue in the existing Wine source. This is x86_64 execution under Rosetta, not an ARM64 implementation. No Rust or Swift EAAC component has been delivered. Preserve the existing Wine, DXMT, mtld3d, and x87 sidecar stack when continuing; changing it would confound launch comparisons.

The installed launcher helper is `/Users/gc/Developer/GameHub/bin/start-ea.sh`. It now chooses the newest installed EA Desktop version using `sort -V` instead of the deleted hard-coded 13.805 path. It selects `/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer` by default, supplies `WINEMSYNC=1`, `WINE_TF_EMULATION=1`, the x87 path, and per-process `WINE_COMPATDB`. EA CEF and EAGEP use wined3d while the default profile uses `d3d9=mtld3d;dxgi=dxmt`. `E:` maps to `/Volumes/ExT2/GameHub`; current `Z:` maps to `/Volumes`. The host working directory is `/Users/gc/Library/Application Support/BF3Mac` and the helper creates HOME/TMPDIR under that runtime home. The helper launches with `nohup` in the background; a tool harness may end its child early, so preserve a foreground parent job for a controlled trace and record the actual process lifetime.

## Windows interface contract established so far

A Microsoft 19041.5794 x64 ntdll reference supplies this 32-byte Zw cell, with a four-byte little-endian number at `<nru32>`:

```text
4c8bd1b8<nru32>f604250803fe7f0175030f05c3cd2ec30f1f840000000000
```

The second instruction path is `int 0x2e`; the cell ends in an eight-byte NOP. The old report's `int 0x29` and `0xcc` padding were wrong. [Microsoft ntdll.dll](https://msdl.microsoft.com/download/symbols/ntdll.dll/3AF2A74F1f8000/ntdll.dll) supplied the reference stub format, corroborated against reference builds 19041.5440 and 19041.6093, but its full-file hash did not match Winbindex metadata, so whole-file independent corroboration is **not** claimed. [Microsoft ntoskrnl.exe](https://msdl.microsoft.com/download/symbols/ntoskrnl.exe/5B5EC8781046000/ntoskrnl.exe) matched checked SHA-256 `f394a43b4aad1936af9a4fc6954904c22b9193a105b26cb9113a18652068eed4`; `NtInitializeRegistry` RVA was `0x78df90` and its invalid-input return near `0x78dff2`. The matching [PDB](https://msdl.microsoft.com/download/symbols/ntkrnlmp.pdb/7A49711F9BF937DF3C52C7A5B94C4DD71/ntkrnlmp.pdb) is available.

| Live raw probe | Windows result |
|---|---|
| `NtWaitForSingleObject(-1, FALSE, &zero)` | `STATUS_TIMEOUT`, `0x00000102` |
| `NtWaitForSingleObject(0xffffffffffffd8f0, FALSE, NULL)` | `STATUS_INVALID_HANDLE`, `0xc0000008` |
| `NtWaitForSingleObject(-1, FALSE, invalid pointer)` | `STATUS_ACCESS_VIOLATION`, `0xc0000005` |
| `NtInitializeRegistry(0xffffffffffffd8f0)` | `STATUS_INVALID_PARAMETER`, `0xc000000d`; low `USHORT=0xd8f0` |

The code validates invalid registry flags, but accepted flags `0`, `1`, `2`, and `0x1000`–`0x13e8` still return `STATUS_NOT_IMPLEMENTED`. Full registry initialization is **not implemented**. Unknown syscall numbers use `STATUS_INVALID_SYSTEM_SERVICE`. Synthetic NTSTATUS errors zero-extend a 32-bit result in `RAX`, matching `mov eax` semantics. The current conversion also handles a valid Wine syscall ID zero via an explicit found result and an offset cache representation. Job 471's 257 stub-image checks demonstrate the current test scope; successful writing of every possible Windows syscall cell is not implied.

The four relevant files are `dlls/ntdll/tests/syscall.c`, `dlls/ntdll/unix/signal_x86_64.c`, `dlls/ntdll/unix/unix_private.h`, and `dlls/ntdll/unix/winsyscall.c`. The signal path identifies a readable-page execute fault, writes resolved ntdll Zw cells through a page protection change, and translates raw or patched-cell syscall numbers through Wine's dispatcher. The native helper enumerates table entries and records successful writes; address membership checks the published list. Current source still merits review of the broad fault trigger, publication during concurrent observation, an RX restore failure that is logged while write success may be returned, and the distinction between table/cache sentinels. These are source risks and follow-up questions, **not established causes of `E111000D`**.

Note: This section describes genuine Windows behavior. The project also implements detection-evasion techniques to mask Wine's identity from the anti-cheat's environment checks; see **Known anti-cheat-evasion techniques already in the tree**, below.

## Known anti-cheat-evasion techniques already in the tree

The following changes exist to make Wine's identity unresolvable by the anti-cheat's probes. They do not fix a Wine compatibility gap; they are detection evasion and are labeled as such.

**Plain statement:** These are not genuine Windows compatibility fixes. They are deliberate transformations of Wine's exposed identity to defeat the anti-cheat's environment detection. The following section describes what they are, how they work, and their deployment status.

(a) **`wine_get_version` export hidden by renaming**
Commit `85195944d91` ("ntdll: Hide the wine_get_version export behind a renamed name") exports it as `xine_get_version` in `dlls/ntdll/ntdll.spec`, so `GetProcAddress` and raw export-table scans for `wine_get_version` fail. The spec comment states: "foreign fingerprinting code probes ntdll for wine-only exports."

(b) **Windows version-resource stamping**
Same commit (`85195944d91`). The file `dlls/ntdll/version.rc` stamps `ntdll.dll` with Windows 10 19045 version metadata (`FILEVERSION 10,0,19045,5804`, product name "NT Layer DLL", company "Microsoft(R) Windows(R) Operating System") instead of Wine's own version string (e.g., Wine 6.1.7601). This is compiled source-level — no post-build stamping tool modifies the binary. The runtime directory name suffix `-noWineVer` in `/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer` reflects this design.

(c) **Windows-byte-identical Zw stub rewrite**
Commit `ed6ebe1c693` ("ntdll: Present Windows 19045 Zw stubs to the EA anti-cheat loader") initially rewrote six stubs. Follow-on work (built as jobs 469–475, committed as `a8187c8c3c9`) extends this to 257 stubs, rewriting them to the Windows 19045 32-byte cell bytes so the loader's hash/byte-pattern check matches Windows exactly. The patching occurs at runtime via signal-handler interception.

**Distinguished from genuine behavioral fixes** in the same diff history, which implement real Windows behavior and are not evasion:
- The syscall-ID +1 sentinel (commit `024031195ba`: "Index the syscall table one past the value encoded in the stubs"; the cache ID + 1 representation for Wine syscall ID zero).
- Correct NTSTATUS codes (e.g., commit `aabb80c26c8`: `STATUS_INVALID_PARAMETER` for unknown NLS section type; `NtWaitForSingleObject`/`NtInitializeRegistry` status behavior).
- Result zero-extension in raw-syscall emulation (ensuring 32-bit results in `RAX` match `mov eax` semantics).

**Decision recorded:** User decision (2026-10-14): leave the existing evasion code as-is, do not extend it further, and label it honestly in all docs going forward.

**Note:** These evasion techniques are present in every archived build (469, 473, 474, 475), including the currently deployed job 475.

## What the launch evidence actually says

EA Desktop's verbose log records `E:\EA Games\F1 24\EAAntiCheat.GameServiceLauncher.exe` as the launch process. F1's content/master title ID is `16425782`; its offer ID is `Origin.OFR.50.0005434`. They are different identifiers. Run-473 (trigger 10:32:15Z) captured the failure as a visible modal Wine dialog (WINDOW_REPORT.txt; screenshots x-win-67014-4185.png and x-win-70273-4188.png) reading “The program encountered E111000D at 0026FA30 during initialization. Conflicting software detected!”. Earlier attempts around 08:44, 09:06 and 09:35 UTC also ended in E111000D but their dialogs were not captured. The reported timings of approximately 27, 169, and 326 seconds likely represent how long that dialog remained open before it was dismissed or the process was killed, not a launcher-internal timer. In run-473, the same dialog stayed open for 16+ minutes untouched. Future runs should capture/screenshot the dialog automatically rather than treat time-to-error as a signal. EA Desktop's subsequent “Post game cloud sync” is cleanup after a session, not game launch evidence.

The install chain has unaddressed gaps that gate before any Wine fix could matter: the F1 license file `C:\ProgramData\Electronic Arts\EA Services\License\16425782.dlf` is missing (see run-473 REPORT.txt line 38; the review reports this causes a 120 s reactivation timeout on each launch attempt), and `eaanticheat.sys` driver file does not exist anywhere in the prefix. These are install-time issues independent of Wine's syscall behavior. The review (EAAC-FULL-REVIEW-20261014.md §2) says a multi-gate ladder (E111000B → E1110005 → E1110009 → E111000D on a second verification round) is in `/Users/gc/Desktop/EAAC-gate5-status-report.md`; it was not found there (that file covers round 2 only). Gate 1 (E111000B) and Gate 2 (E1110005/E1110009) history is in `/Users/gc/Desktop/EAAC-handoff-report.original-20261014-1033.md` (lines 105–111).

In a historical long run, the launcher requested `EAAntiCheatService` through SCM. A later direct `sc start EAAntiCheatService` returned 1053. A direct service executable run lasted about seven minutes until prefix shutdown; elapsed time does not establish SCM readiness. The prefix lacks `system32/drivers/eaanticheat.sys` at its declared location. There is no demonstrated causal connection between that missing file and the current `E111000D`, although it is a concrete protection-readiness gap to investigate. No `d3d12.dll` was found in the searched GameHub runtimes, BF3Mac, and `/Users/gc/Games` locations. The game contains D3D12 symbols and `D3D12Core.dll`, making graphics readiness a later question; no actual F1 loader error has been observed because the game process has not started.

Earlier `Z:` experiments changed observed results, but they did **not** prove that the launcher scans visible forensic files or a Unix namespace marker. Standalone launcher exits can occur before work reached in an EA Desktop launch. The offline `/tmp/emu/harness` produced a 7,065-step trace to a harness-inserted verdict-address sentinel, but its one `emu_rax` value represented all emulated syscalls, unlike the distinct live probes. It cannot prove the late predicate, a live `INT3` at that address, or the absence of an earlier byte check. Historical dumps retained a 24-qword header yet have magic `0xeaacd00000000005` (version 5, despite the old “v4” label). The old temporary capture writer has been removed from current source and deployed runtime; historical `/tmp/eaac-full-*.bin` files may still exist and may contain authentication data. Do not share or embed raw dumps.

## Reproduce and diagnose without changing the experiment

1. Capture HEAD, `git status` output, the deployed `ntdll.so` hash, EA Desktop version, `dosdevices` links, and the exact `HUB_RUNTIME`, `HUB_X87_PATH`, `HUB_X87`, and `HUB_WINEDEBUG` overrides. The deployed hash is job 476 (92a07523…). Job 475 (fb185cd9…), Job 473 (313e87df…), and Job 469 (d585a642…) are archived under /Users/gc/eaac-archive/codex-20261014/.
2. Launch EA Desktop with `/Users/gc/Developer/GameHub/bin/start-ea.sh` from its normal host environment, then choose F1 24. Record the printed PID and log path. Do not substitute a direct launcher executable for the authenticated EA Desktop flow when evaluating the full objective.
3. Use narrow process/service/SCM/SEH channels; the recorded narrow profile was `warn,EAAntiCheat.GameServiceLauncher.exe:trace+seh,process,service,scm,eaanticheat.gameservice.exe:trace+seh,process,service,scm,F1_24.exe:trace+seh,process`. Prior `+relay` changed procedure-resolution observations and `+module` coincided with startup instability. Keep them off for comparable logs.
4. Correlate EA Desktop's `launchGameProcess` line, launcher lifetime, raw probe arguments, any SCM transition, service status, F1 process creation, visible error, and terminal cleanup. A process that exists or a cloud sync line alone does not satisfy service/game criteria. Preserve UTC and elapsed time.
5. Redact tokens/session values in any shared manifest. Include binary hash, source state, title IDs, configuration, and relevant log paths. Logs may contain sensitive account data. Do not copy authentication values from old dumps into a new launch.

Useful locations: `/Volumes/ExT2/GameHub/Prefix/drive_c/ProgramData/EA Desktop/Logs/` for EA logs; `/Volumes/ExT2/GameHub/Hub/Logs/ea-<timestamp>.log` for helper output; `/Users/gc/eaac-archive/codex-20261014/ea-20261014-111340.log` (large file-debug) and `ea-20261014-112648.log` (narrow) for earlier reference. The pre-canonical runtime backup is `/Users/gc/eaac-archive/codex-20261014/ntdll-before-canonical.so`. It is a rollback artifact with older behavior, not a solution. To roll back a broken deployed ntdll, stop the affected prefix, preserve the current binary/hash and failure log, restore only the backup `ntdll.so` via atomic rename in the corresponding runtime, restart, and record which build loaded. Do not overwrite the source tree (clean at `e8d83a5d09d` on `eaac-ntdll-20261014` as of 14 Oct; wine is now on `main` at /Users/gc/Developer/wine, moved 2026-10-15) or the user's prefix.

## Risks and constraints

EA Sports' anti-cheat explicitly disallows Wine/Proton. The deployed runtime (job 473 and later) presents a spoofed Windows identity to the anti-cheat via the evasion techniques described above (see "Known anti-cheat-evasion techniques already in the tree"), so every launch with it risks account action under EA's Terms of Service on the account used — which to date is the user's real account. **Recommendation:** use a throwaway EA account for any further anti-cheat-facing experiments on this runtime.

Work lives on one external volume (`/Volumes/ExT2`, currently ~80% full) with no second copy. Logs may contain account tokens, session identifiers, or other sensitive data. Keep the entire work directory and any captured reports private regardless of public sharing of code or findings.

## Next evidence, in order

1. Job 476: trace OBJECT_ATTRIBUTES->ObjectName for the file/registry probes (see `/Users/gc/Desktop/EAAC-handoff-report.md`, "Next, in order"). Re-run the focused and virtual suites against whatever build is to be deployed and record which build was deployed at test time; use the same harness as jobs 471/472/475.
2. Once test results are available, resolve whether to run further diagnostic EA Desktop attempts. If running, use an atomic replacement, record its SHA-256 and source identity, and run one controlled authenticated attempt. Use its `NtTerminateProcess` caller/argument and failed-translation traces to frame a falsifiable cause for `E111000D`. Compare against the last recorded live trace while accounting for its different runtime revision. Do not assert a filesystem, driver, status, or byte predicate without separating evidence.
3. Determine SCM service state and actual protection dependency during the same run. A direct service executable process and `sc start` 1053 are separate observations.
4. Look for `F1_24.exe` creation before investigating F1 graphics failures. If it starts, inspect actual DLL loads and render path; then assess active protection and repeatability.
5. Establish a performance baseline only after a playable protected run. No startup/frame pacing, CPU, GPU, energy, or disk comparison has been measured, so no smoothness claim is supported.

The wider report collection has a draft inventory of 1,729 unique documents with original sources preserved; synthesis/index is pending and no completed project-wide bundle should be inferred. A separate checkpoint is saved at `/Users/gc/Desktop/EAAC-WHERE-WE-LEFT-OFF-20261014.md`. Temporary foreground work job 448 and `/tmp` wrappers require status checks before reuse or cleanup; do not assume they still run. The original 10:33 report archive stays immutable. The job 476 work was committed as `e8d83a5d09d` on branch `eaac-ntdll-20261014` (14 Oct; wine is now on `main` at /Users/gc/Developer/wine, moved 2026-10-15) and pushed with tag `eaac-job476-92a07523`; no rebases.

**Resume summary:** job 476 (92a07523…) is deployed and tested (352 checks, 0 failures, 0 todo, 0 flaky). Job 475 (fb185cd9…), job 473 (313e87df…), and job 469 (d585a642…) are archived. C1/M2 publication race, C4 NtInitializeRegistry status, C5 Rosetta MXCSR on int 0x2e, and C3 mprotect error escalation are fully resolved.
