# EAAC / F1 24 on macOS — Comprehensive Findings & Remediation Report (Job 476)

> Wine source: now at /Users/gc/Developer/wine (moved 2026-10-15), branch `main`. Former `/Volumes/ExT2/GameHub/src/wine` paths in this document are rewritten to that location; `eaac-ntdll-20261014` and `development` mentions are 14 Oct history.

**Date:** 2026-10-14 14:55 CEST  
**Location:** `/Users/gc/Developer/wine`  
**Git Branch:** `main` (wine now at /Users/gc/Developer/wine, moved 2026-10-15; the job 476 commit `e8d83a5d09d` and tag `eaac-job476-92a07523` were made on 14 Oct on branch `eaac-ntdll-20261014`)  
**Deployed Binary:** `ntdll.so` (SHA-256: `92a0752306fc61a2e21b194f9125d60d92d71b6af5f3dd1aaf5c2e76190858a1`)  
**Target:** EA AntiCheat (Javelin) compatibility and full F1 24 execution on macOS Apple Silicon (M2 Pro, Rosetta 2)

---

## 1. Executive Summary & Status

Job 476 has been engineered, compiled, tested, archived, and atomically deployed to the active runtime at `/Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer/lib/wine/x86_64-unix/ntdll.so`.

- **All 4 Identified Wine Defects (C1/M2, C4, C5, C3) Are Fixed**:
  - Publication race in stub rewriting eliminated.
  - `NtInitializeRegistry` status aligned with genuine Windows 10/11 post-boot semantics (`STATUS_ACCESS_DENIED`).
  - Rosetta 2 floating-point MXCSR state corruption eliminated on the `int 0x2e` dispatch path.
  - Memory protection failures escalated to `ERR_(seh)`.
- **Test Suite Results**:
  - `352` tests executed, `0` failures, `0` marked todo (down from 2 in Job 475), `0` flaky. All 257 Zw stubs verified.
- **Repository State**:
  - Clean working tree, committed (`e8d83a5d09d`, 14 Oct, on branch `eaac-ntdll-20261014`; wine is now on `main` at /Users/gc/Developer/wine, moved 2026-10-15), tagged `eaac-job476-92a07523`, and pushed to remote `origin` (`github.com:g-cqd/wine`).
- **Archive Status**:
  - Binary archived at `/Users/gc/eaac-archive/codex-20261014/ntdll-job476-92a07523.so`.
  - Diff patch archived at `/Users/gc/eaac-archive/codex-20261014/wine-src-diff-job476.patch`.
  - HEAD reference archived at `/Users/gc/eaac-archive/codex-20261014/job476-HEAD.txt`.

---

## 2. The E111000D Modal Dialog Mystery Solved

Earlier sessions noted erratic execution durations for the EAAC preloader (27 s, 169 s, 326 s) before termination with code `0xE111000D`. This was previously hypothesized to be an internal anti-cheat watchdog timer.

### Root Cause: Win32 Modal Dialog `#32770`
- Detailed window tree inspection (`WINDOW_REPORT.txt` in `run-473-20261014-102650`) and archived window captures (`x-win-67014-4185.png`, `x-win-70273-4188.png`) revealed that the launcher creates a hidden Win32 dialog:
  - **Class:** `#32770` (Standard Dialog)
  - **Dimensions:** 156 x 83
  - **Text:** *"The program encountered E111000D at 0026FA30 during initialization. Conflicting software detected!"*
- Because EA Desktop sits in front of the Wine desktop without ceding focus, the modal dialog remains invisible behind the EA app.
- The launcher enters a standard Windows message pump (`GetMessage`/`DispatchMessage`) waiting indefinitely for the user to click "OK".
- The earlier timings (27 s, 169 s, 326 s) simply measured the duration until an operator or test harness killed the process or clicked through the window.

---

## 3. Decoded EA Javelin AntiCheat Error Code Table

Reverse-engineering of the EAAC preloader images (`preloader_s.dll` and `preloader_l.dll`) isolated the definitive error dispatch table located at RVA `0x6b88`:

| Error Code | Official EA AntiCheat Message String | Security Gate / Trigger Context |
|------------|--------------------------------------|---------------------------------|
| `0xE1110000` | "Unexpected error during initialization" | Generic failure fallback |
| `0xE1110001` | "This Operating System version is not supported!" | Major OS version mismatch |
| `0xE1110002` | "Windows XP x64 is not supported. Please use a newer operating system!" | Pre-Vista legacy reject |
| `0xE1110003` | "Windows Vista is not supported. Please use a newer operating system!" | Vista legacy reject |
| `0xE1110005` | "Windows 7 is not supported. Please use a newer operating system!" | Gate 2: Windows 7 PE version reject |
| `0xE1110006` | "Windows 8 is not supported. Please use a newer operating system!" | Windows 8 reject |
| `0xE1110008` | "Windows 8.1 is not supported. Please use a newer operating system!" | Windows 8.1 reject |
| `0xE1110009` | "Windows 10 Beta is not supported. Please use a newer operating system!" | Gate 3: `dwFileVersionLS` build reject |
| `0xE111000A` | "Your Windows 10 install is too outdated. Please install Windows 10 1809 or newer!" | Build threshold < 17763 |
| `0xE111000B` | "Wine, Proton, and Steam Deck are not supported by this application!" | Gate 1: Export scan for `wine_get_version` |
| `0xE111000C` | "Invalid version info structure!" | Corrupted PE version resource header |
| `0xE111000D` | "Conflicting software detected!" | Gate 5: Griffin unpack / hypervisor / VM detection |
| `0xE111000E` | "File version mismatch between the preloader and runtime DLLs. Please repair or reinstall the application." | Mismatched preloader / GameService versions |
| `0xE111000F` | "Syscall emulation is disabled in this Wine build. Please use a version with syscall emulation enabled." | Missing raw syscall interception |
| `0xE1110011` | "Windows 10 is not supported. Please use a newer operating system!" | Deprecated build variant |
| `0xE1110012` | "Windows on ARM is not supported. Please use a x86-64 CPU!" | ARM64 CPU architecture check |
| `0xE1110013` | "Windows on ARM requires Windows 11 24H2 or later. Please use a newer operating system!" | Windows ARM64 build requirement |

---

## 4. Official CDN Ingestion & Driver Architecture Findings

### Investigation Summary
1. **Endpoint Identified**:
   - `https://cdn.eaanticheat.ac.ea.com/EAAntiCheat.Installer.exe`
2. **Package Retrieved & Ingested**:
   - Downloaded 277 MB installer (`277,175,032 bytes`, SHA-256 `d0396b7f...`, build timestamp `2026-10-08 22:45 UTC`, version `1.0.15973373.0`).
   - Replaced old local `C:\Program Files\EA\AC\EAAntiCheat.Installer.exe`.
   - Updated runtime components `EAAntiCheat.GameService.exe` (190 MB) and `EAAntiCheat.GameService.dll` (63 MB) deployed to `C:\Program Files\EA\AC\`.
3. **Automated GUI Trigger (`click_eaac.exe`)**:
   - Compiled Win32 helper `/tmp/click_eaac.c` with the MinGW toolchain.
   - Located the active setup dialog (`hwnd 0x000D01AA`, title `"EA Javelin Anticheat Setup"`).
   - Fired `BM_CLICK` (`0x00F5`) at the "Repair" button (`id 0x00060182`), completing an in-prefix repair pass.
4. **Driver Packaging Architecture (`eaanticheat.sys`)**:
   - The installer does not contain a loose `.sys` file in its PE overlay or ZIP directories.
   - The kernel driver is embedded inside the encrypted `.grfn` (Griffin) payload sections of `EAAntiCheat.GameService.exe` (190 MB).
   - On genuine Windows, `GameService.exe` installs and starts the kernel service via the Windows Service Control Manager (`CreateServiceW` / `StartServiceW`), dropping `eaanticheat.sys` into `System32\drivers\`.
   - In Wine, executing `EAAntiCheat.GameService.exe` triggers deliberate SEH fault probes (e.g. `MD5Init` NULL dereference at offset `0x14` caught by `RtlUnwindEx`) and over 270 `NtProtectVirtualMemory` protection toggles.
   - **Conclusion**: Pathway A (extracting `eaanticheat.sys` directly from an operational Windows system) is the only realistic route for driver acquisition.

---

## 5. Wine Core Defects Remediated in Job 476

### Defect 1: C1 / M2 — Publication Race & Atomicity in Stub Rewriting
- **File:** [`dlls/ntdll/unix/winsyscall.c`](file:///Users/gc/Developer/wine/dlls/ntdll/unix/winsyscall.c) and [`dlls/ntdll/unix/signal_x86_64.c`](file:///Users/gc/Developer/wine/dlls/ntdll/unix/signal_x86_64.c)
- **Problem:** `eaac_patch_stubs_native` previously wrote stub addresses into `eaac_patched_stubs` but updated `*published_count` only after the entire 257-stub loop finished. Concurrent threads executing newly modified stubs hit `int 0x2e` while `is_patched_stub_address()` returned `FALSE`, treating the call as an unhandled crash or dispatching raw Windows syscall numbers as Wine IDs. Furthermore, `write_windows_stub_image` wrote bytes from offset 0 upwards, risking execution of torn stub instructions.
- **Solution:**
  1. In `write_windows_stub_image`, offsets 24, 16, and 8 are written first, and the 8-byte header (`mov r10, rcx; mov eax, <nr>`) is committed last in a single, indivisible 64-bit aligned store (`movq`).
  2. In `eaac_patch_stubs_native`, `*published_count` is updated immediately following each successful stub write.
  3. In `is_patched_stub_address`, a lock-free signature check (`words[1] == 0x017ffe03082504f6ULL && words[2] == 0xc32ecdc3050f0375ULL`) validates rewritten stubs within the ntdll image in $O(1)$ time.

### Defect 2: C4 — `NtInitializeRegistry` Status Code Alignment
- **File:** [`dlls/ntdll/unix/signal_x86_64.c`](file:///Users/gc/Developer/wine/dlls/ntdll/unix/signal_x86_64.c)
- **Problem:** `unsupported_windows_syscall_status` returned `STATUS_NOT_IMPLEMENTED` (`0xC0000002`) for accepted `NtInitializeRegistry` flags (`flags <= 2` and `0x1000 <= flags <= 0x13e8`). Real Windows 10/11 x64 returns `STATUS_ACCESS_DENIED` (`0xC0000022`) post-boot, allowing anti-cheat probes to detect Wine emulation.
- **Solution:** Updated `unsupported_windows_syscall_status` to return `0xC0000022` for valid flags, `0xC000000D` (`STATUS_INVALID_PARAMETER`) for out-of-range flags, and `0xC0000002` for all other unsupported syscalls. Removed `todo_wine_if` in [`dlls/ntdll/tests/syscall.c`](file:///Users/gc/Developer/wine/dlls/ntdll/tests/syscall.c).

### Defect 3: C5 — Rosetta 2 MXCSR Correction on `int 0x2e` Path
- **File:** [`dlls/ntdll/unix/signal_x86_64.c`](file:///Users/gc/Developer/wine/dlls/ntdll/unix/signal_x86_64.c)
- **Problem:** The Apple Silicon Rosetta 2 floating-point fix ("CW Hack 24265") was applied on `SIGSYS`, but omitted on the `int 0x2e` (SEGV/BUS) path used by rewritten stubs.
- **Solution:** Factored Rosetta MXCSR synchronization into an inline helper `check_rosetta_mxcsr( ucontext_t *ucontext )` and hooked it into the return path of `segv_handler` for `int 0x2e`.

### Defect 4: C3 — Escalate `mprotect` Failures
- **File:** [`dlls/ntdll/unix/signal_x86_64.c`](file:///Users/gc/Developer/wine/dlls/ntdll/unix/signal_x86_64.c)
- **Problem:** Protection errors when toggling stub memory from RX to RWX and restoring to RX were logged at `TRACE_(seh)` level, masking silent failures.
- **Solution:** Escalated all `mprotect` failure logs in `write_windows_stub` to `ERR_(seh)`.

---

## 6. Audit of Remediation Plan `EAAC-REMEDIATION-S1-S3.md`

A review of `/Users/gc/Desktop/EAAC-REMEDIATION-S1-S3.md` confirmed 8 critical defects that prevent running it as written:
1. **Incorrect Rollback Target:** S3 points to an older job rather than the immediate predecessor.
2. **Dangling Symlink Risk:** Attempts to link runtime folders without verifying existing absolute targets.
3. **No-Op Checksum Logic:** Validation steps compare identical variables rather than comparing target to expected golden hash.
4. **Non-Blocking Signature Gate:** Security checks issue warnings but exit with code 0 instead of aborting.
5. **Post-Migration Scan Gap:** Omits validating PE header characteristics after moving DLLs.
6. **Destructive Backup Overwrite:** Second backup command overwrites original pre-patch backup without timestamping.
7. **Incomplete Runtime Build:** Invokes `make` without specifying the full target architecture flags.
8. **Unguarded `rm -rf`:** Contains unquoted path expansions that could target parent directories if variables are unset.

---

## 7. Build, Deployment, and Test Verification Matrix

| Metric | Job 475 (Prior) | Job 476 (Current Deployed) |
|---|---|---|
| **Commit** | `a8187c8c3c9` | `e8d83a5d09d` |
| **Git Tag** | `eaac-job475-fb185cd9` | `eaac-job476-92a07523` |
| **`ntdll.so` SHA-256** | `fb185cd96f6eee08345b37131f7e2f6864f25c5e83b9af2f4c763172fd5366a0` | `92a0752306fc61a2e21b194f9125d60d92d71b6af5f3dd1aaf5c2e76190858a1` |
| **Atomic Deploy Method** | `rename(2)` via `.ntdll.so.new.$$` | `rename(2)` via `.ntdll.so.new.$$` |
| **Deployed Path** | `/Volumes/ExT2/.../ntdll.so` | `/Volumes/ExT2/.../ntdll.so` |
| **Syscall Test Suite** | 352 checks (2 marked todo) | **352 checks (0 todo, 0 flaky, 0 failures)** |
| **Zw Stubs Patched** | 257 / 257 resolved | **257 / 257 resolved (atomic write + lock-free signature)** |
| **NtInitializeRegistry** | `STATUS_NOT_IMPLEMENTED` | **`STATUS_ACCESS_DENIED` (Windows 10/11 match)** |
| **Rosetta MXCSR on int 0x2e** | Not implemented | **Active via `check_rosetta_mxcsr`** |

---

## 8. Next Operational Step

With Job 476 deployed and passing 100% of the focused ntdll syscall test suite, the runtime is primed for live launcher validation:
1. Ensure stale background processes are cleared (`kill -9 95336` or normal quit).
2. Launch EA Desktop and initiate F1 24 launch monitoring:
   ```bash
   /Users/gc/Developer/GameHub/bin/start-ea.sh
   ```
3. Observe if the launcher transitions past Gate 5 without generating the `E111000D` modal dialog.
