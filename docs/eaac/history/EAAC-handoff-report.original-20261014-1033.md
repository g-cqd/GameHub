> Superseded — see docs/eaac/ for the current version.
# EA Anticheat (EAAC / Javelin) on macOS — Comprehensive Handoff Report

Date: 2026-10-14 10:35 CEST
Author: Mistral Vibe session (continuing work by the user and a prior session)
Audience: any developer continuing the effort to run EAAC-protected games
(F1 24) under Wine/CrossOver on Apple Silicon.

---

## 1. Mission and current status

**Goal:** Run F1 24 (EA Javelin / "EA anticheat" protected) under a CrossOver-derived
Wine build on Apple Silicon (M2 Pro, macOS 27.x, Rosetta 2 x86_64 translation),
launched through EA Desktop.

**Status in one paragraph:** Gates 1–5 of the anticheat init are all SOLVED and the
loader gets past every early check — including the Zw-stub fingerprint round —
reliably. The full EA Desktop launch flow gets as far as the launcher passing all
checks, running its real logic for minutes (dispatching thousands of syscalls
through patched stubs), and (in the best observed run) starting the EAAC service
directly via SCM. What is NOT yet achieved: (a) a fully reliable late-phase check —
a "round 2" verification, firing roughly 5–7 minutes into the launcher's wait
phase, still fails with E111000D "Conflicting software detected!" in EA Desktop
launches; (b) F1_24.exe never spawns yet. The round-2 check is at least partly an
environment scan (see the Z: drive section) and its exact predicate is not yet
fully decoded.

---

## 2. Environment, paths, and key components

| Component | Path / value |
|---|---|
| Machine | MacBook M2 Pro, macOS 27.2, Rosetta 2 for x86_64 |
| Wine source tree | /Volumes/ExT2/GameHub/src/wine — fork g-cqd/wine, branch `development` |
| Runtime (deployed build) | /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer |
| Wine prefix | /Volumes/ExT2/GameHub/Prefix (dosdevices: c:→drive_c, e:→/Volumes/ExT2/GameHub, z:→/Volumes) |
| EA Desktop (NEW, self-updated) | C:\Program Files\Electronic Arts\EA Desktop\13.809.0.6322-1791939025\EA Desktop\EADesktop.exe |
| EA Desktop (OLD — now DELETED) | ...13.805.99.0\EA Desktop\EADesktop.exe (start-ea.sh still points here — BROKEN) |
| Game | E:\EA Games\F1 24 (E:→/Volumes/ExT2/GameHub) |
| Game entry exe | E:\EA Games\F1 24\EAAntiCheat.GameServiceLauncher.exe — EA Desktop treats THIS as "the game" |
| EAAC service exe | C:\Program Files\EA\AC\eaanticheat.gameservice.exe (registry name EAAntiCheatService, demand start) |
| EAAC kernel driver | system32\drivers\eaanticheat.sys — NOT INSTALLED in the prefix (wine cannot load it) |
| Launch helper scripts | /Volumes/ExT2/GameHub/bin/start-ea.sh (old path, needs update), /tmp/ea-launch-new.sh (works, new path) |
| Standalone launcher test script | /tmp/eaac-retest-launcher.sh (runs the launcher directly, WINEDEBUG spec for launcher channels) |
| Window/dialog detector | /tmp/winspy.exe (source /tmp/winspy.c, built with the llvm-mingw toolchain below; NOTE: currently hangs in sessions where EA Desktop 13.809 is running) |
| LLVM-MinGW toolchain | /Volumes/ExT2/GameHub/toolchains/llvm-mingw-20261006-ucrt-macos-universal |
| Offline replay harness | /tmp/emu/harness (source harness.c; replays v4 dumps; EAAC_TRACE env writes per-step rip/rsp/rcx/rdx/r8/r9) |
| Guest-state dumps | /tmp/eaac-full-<pid>.bin (v4 format, written by TEMPORARY code in the deployed ntdll.so — see §6) |
| Offline reference captures kept | /tmp/eaac-full-56046.bin, -99957.bin, -11171.bin (failing states, Z:→/ era) |
| Archive of logs | /Users/gc/eaac-archive/ (moved out of the E:-visible tree deliberately) |
| EA Desktop logs | <prefix>\drive_c\ProgramData\EA Desktop\Logs\ (EADesktopVerbose.log etc.) |
| Wine session log | /Volumes/ExT2/GameHub/Hub/Logs/ea-<timestamp>.log (per launch via start-ea.sh) |

Environment variables that matter for a launch (full tested set is in
/tmp/ea-launch-new.sh): WINEPREFIX, WINEMSYNC=1, ROSETTA_X87_PATH=<runtime
helpers>/x87sidecar, WINE_COMPATDB (per-exe dxgi/d3d9 selection),
WINEDLLOVERRIDES="IGOProxy32.exe=d;winemenubuilder.exe=d", WINE_TF_EMULATION=1,
WINEDEBUG="warn,EAAntiCheat.GameServiceLauncher.exe:trace+seh,process,service,scm,F1_24.exe:trace+seh,process".
USER=Player, HOME=<BF3Mac>/RuntimeHome/Player, TMPDIR=<BF3Mac>/Temporary, and
cd into "/Users/gc/Library/Application Support/BF3Mac" before starting wine.

---

## 3. How EAAC works (what we verified, not assumed)

1. **The launcher is the game's exe.** EA Desktop runs
   EAAntiCheat.GameServiceLauncher.exe as if it were the game and monitors it as a
   game process. On Windows the launcher: runs integrity checks, receives EA's
   launch context via environment variables (~35 EA* vars incl. EALicenseToken,
   OriginSessionKey, EAGenericAuthToken — extracted verbatim from a live dump,
   see /tmp/eaac-full-72165.bin), starts the EAAC service via SCM
   (OpenService("EAAntiCheatService") + StartService — verified live), and later
   spawns the real game exe. F1_24.exe is NEVER created by EA Desktop directly.
2. **The stage-2 module**: a ~24MB VMProtect-obfuscated DLL mapped at 0x100100000
   in the launcher process; the verdict dispatch (all E11xxxx errors) funnels to
   INT3 sites: launcher RVA 0x0026FA30 (abs 0x10036fa30), service RVA 0x0046A284.
3. **The "self-decrypt dance"**: the preloader (preloader_l.dll, mapped around
   0x6ffffd320000 in older sessions; varies) deliberately execute-faults on a
   page mapped readable-but-not-executable; wine's SEH turns it into control
   flow. The dance is the first EAAC-specific event and our patch hook.
4. **The stub fingerprint rounds**: between checks the loader resolves ntdll Zw
   exports and hashes their bytes. Round 1 hashes a FIXED, CONSECUTIVE list of
   stubs (NOT random): rvas 0x56e30..0x57050 = ZwSetInformationKey,
   ZwSetInformationToken, ZwSetInformationVirtualMemory, ZwSetIntervalProfile,
   ZwSetIoCompletion, ZwSetIoCompletionEx, ZwSetSystemInformation,
   ZwSetSystemTime, ZwSetThreadExecutionState, ZwSuspendProcess,
   ZwSystemDebugControl (and likely more past 0x57050). A LATER round ("round 2")
   fires minutes into the run and is the current blocker (see §7).
5. **Raw syscall probes**: the module executes raw `syscall` instructions with the
   Windows ABI (nr in eax, arg1 in r10): observed nr 0x4 (NtWaitForSingleObject)
   ×3 sites (abs 0x1004059b1, 0x100417be6, 0x1003f5e3f) and nr 0x101
   (NtInitializeRegistry). Under our runtime these raise SIGSYS and are
   dispatched to the matching wine function (see §5).
6. **Environment scanning**: the loader checks its environment and the
   filesystem. This build (Sep 2024) has NO proton/steam compatibility path —
   the "Wine not supported" stance is absolute. It reads the process environment
   (90 variables observed in a live capture) and scans drives — see §7 for the
   Z: findings.

---

## 4. Gates and their status (chronological)

- **Gate 1 (E111000B "Wine not supported")** — SOLVED (commit 85195944d91):
  ntdll exports `wine_get_version` renamed to `xine_get_version` (export rename
  only; implementation unchanged; wine_get_host_version/build_id kept because
  wine's own shell32 imports them by name).
- **Gate 2 (E1110005/E1110009 version checks)** — SOLVED (same commit):
  ntdll.dll version resource baked to Windows 10 19045.5804 (NT Layer DLL,
  Microsoft Corp). Note: transposing the LS dwords produces E1110009.
- **Gate 4 (version functions / registry)** — SOLVED earlier (AppDefaults
  Version=win10 etc.).
- **Gate 5 round 1 (E111000D at 0026FA30, the Zw-stub hash)** — SOLVED
  (commit ed6ebe1c693 + uncommitted upgrades; see §5).
- **"Round 2" (late E111000D, same site)** — OPEN. Fires ~5–7 minutes into the
  EA-context launcher's run. Partly environmental (Z: drive!), exact predicate
  not fully decoded. See §7.
- **Post-antichehe gaps**: launcher's service start and game spawn — best run
  got as far as service start + clean launcher exit; EA Desktop then concluded
  "game ended" and did post-game cloud sync. F1_24.exe has never spawned.

---

## 5. The committed/uncommitted wine fixes (technical detail)

### Committed — ed6ebe1c693 "ntdll: Present Windows 19045 Zw stubs to the EA anti-cheat loader"
- **Dance trigger**: in segv_handler, a SIGSEGV/SIGBUS with si_code SEGV_ACCERR
  (or BUS_ADRERR) where rip faults on a page mapped readable-but-not-executable,
  once per process → patch the fingerprinted Zw stubs before the loader reads them.
- **Stub patch**: rewrite each stub with the byte-exact Windows 10 19045 stub
  (mov r10,rcx; mov eax,nr; test byte [0x7ffe0308],1; jne +3; syscall; ret;
  int 0x29; ret), stubs resolved BY EXPORT NAME via the live image's export
  table (rebuild-proof).
- **int 0x29 interception**: wine sets KUSER_SHARED_DATA SystemCall=1, so a
  call through a patched stub branches to the Windows fastfail tail. The segv
  handler recognizes int 0x29 at patched-stub+0x15 and dispatches through the
  wine syscall frame with the Windows nr translated to the wine id.
- **SIGSYS translation**: foreign (raw) syscalls dispatch by Windows number via a
  473-entry Windows 19045 table (win10_19045_syscalls.h); patched stubs raising
  SIGSYS get the same translation (rip or rip-0x14 check).
- **Export-table off-by-one fix**: AddressOfNameOrdinals entries are DIRECT
  indices into AddressOfFunctions; the old code subtracted Base and compensated
  with +1 — silently mis-resolving stubs like ZwTraceEvent (dispatched foreign
  calls to the wrong function).
- **Tests** (dlls/ntdll/tests/syscall.c): deliberate execute fault on a
  read-only page triggers the patch; asserts the stubs hold Windows bytes and a
  call through patched ZwSetThreadExecutionState still works.

### Uncommitted on top of ed6ebe1c693 (all TDD-green, 33/33 in the syscall suite)
- **Patch-all-257**: winsyscall.c `eaac_patch_windows_zw_stubs()` rewrites EVERY
  wine syscall stub that has a known 19045 number (257 of 473 names resolve),
  because round 1 hashes a fixed list that extends beyond the original six.
  is_patched_stub_address()/the patched-registry moved to winsyscall.c.
- **32-byte stub cell**: write_windows_stub now writes 24 instruction bytes plus
  8× 0xcc padding — the old code had a `[23]`-array-with-24-initializers bug
  (compiler dropped the final c3) and left wine's `jmp *[0x7ffe1000]` tail at
  +0x18, which is part of the hashed cell. CAVEAT: verify real 19045 padding is
  cc if this angle returns.
- **int29 dispatch via syscall frame**: the interception now builds the wine
  syscall frame (frame->rip = stub+0x1f so the dispatcher's −0xb lands at the
  stub's ret; RIP=__wine_syscall_dispatcher_prolog_end) because the wine tail at
  +0x18 is now cc padding.
- **Tests extended** to assert the full 32-byte window.
- **TEMPORARY dump code (4 marked blocks + fcntl include)** in
  signal_x86_64.c: dump_write_range + dump_eaac_v4, firing at the FIRST foreign
  SIGSYS per process, writing /tmp/eaac-full-<pid>.bin (v4 format: 24-qword
  header + 24MB module @0x100100000 + stack + Zw thunk bytes + preloader + a
  mach_vm_region walk of exe/DLL/low ranges, page-safe). ~700MB per EAAC
  process. STRIP THIS before any upstreaming; keep for forensics meanwhile.

### Regression status
- syscall suite 33/33; virtual suite 2335/2335; exception suite byte-identical to
  the pre-change baseline (it dies at a known Rosetta privileged-instruction
  test — 11 pre-existing failures — and leaves a spinning process; kill it).
- Deployed runtime ntdll.so = current tree build (patch-all + 32-byte + dump
  code). Backups in the runtime dir: ntdll.so.bak-20261013-prod (six-stub build),
  .bak-20261013-regs, .orig-aot; PE ntdll.dll.bak-20261013-prod.

---

## 6. Tooling built this session

1. **/tmp/winspy.exe** (source /tmp/winspy.c): EnumWindows dump of pid/class/text
   for every top-level window — the way to see EAAC's modal E111000D dialogs
   (they are real #32770 "Error" dialogs owned by the launcher/service, often
   invisible behind the EA window; the user CAN see them on the Mac screen —
   wine's mac driver shows them). Currently hangs in the 13.809 session (see
   §8); rebuild with the toolchain in §2 if needed.
2. **/tmp/emu/harness**: offline replayer for v4 dumps. Maps the captured state
   (module, stack, regions demand-paged), registers the crossarch syscall
   filter, emulates the probe SIGSYS like the runtime, detects the verdict INT3
   at 0x10036fa30. EAAC_TRACE=<file> writes per-step records (rip, rsp, rcx,
   rdx, r8, r9) — extended this session from 16 to 48 bytes. EAAC_ALARM env for
   timeout, argv[3] sets the emulated probe rax.
3. **Dump-patch experiments** (python, in this session's history and in
   /tmp/emu/*.py): how to locate the ntdll region in a v4 dump's region walk and
   rewrite stub bytes (cc-padding experiments).
4. **Launch scripts**: /tmp/ea-launch-new.sh (EA Desktop 13.809 with the full
   env — the working launcher), /tmp/eaac-retest-launcher.sh (standalone
   launcher oracle), /tmp/eaac-service-run.sh (direct service run).
5. **ps sampler**: /tmp/eaac-ps-sampler.sh → process-timeline2.log (now archived
   at /Users/gc/eaac-archive/eaac-capture-20261012-231849/).

---

## 7. The Z: drive discovery and the round-2 problem (CRITICAL for the next dev)

**Finding:** the prefix had `z: -> /` (GameHub default), making the ENTIRE macOS
filesystem visible to the guest as Z:\. The anticheat's round-2 check scans
reachable drives and flags "conflicting software" — which was LITERALLY correct:
our own forensic artifacts were visible (700MB /tmp/eaac-*.bin dumps, the
harness, the wine source tree full of EAAC patches, EAAC-named capture logs).
Evidence matrix:

| Config | Result |
|---|---|
| Z:→/ with artifacts | random pass/fail (passes at 23:53–00:00, fails 00:13+) |
| Z: absent | 6/6 anticheat passes — but launcher exits ~75s and never reaches the service-start phase |
| Z:→/Volumes (recommended) | deterministic pass + launcher persistent-waits like the passing runs; artifacts in /tmp and /Users are hidden; the GameHub tree stays reachable (same as via E:) |

Current prefix config (KEEP): z: → /Volumes. Logs/captures were moved to
/Users/gc/eaac-archive so E:\Hub\Logs has no EAAC-named content. NOTE: the wine
source tree (/Volumes/ExT2/GameHub/src/wine — reachable as E:\src\wine and
Z:\Volumes\ExT2\GameHub\src\wine) contains EAAC-named code/comments and was
present during passing runs, but a randomized scan could still hit it; consider
relocating the tree out of /Volumes if flakiness returns.

**Remaining round-2 facts (all verified):**
- The verdict fires LATE — ~5–7 minutes into the EA-context launcher's run
  (after ~1800–3700 real stub calls — the launcher is genuinely working by then:
  message pump, window creation, etc.).
- Offline replay from a probe-state dump REPRODUCES the verdict (harness:
  "VERDICT SITE REACHED, 7065 steps"), so the pre-probe memory state contains
  the decision inputs. Flow decoded: probe stub 0x1004059af → MBA handler pages
  0x101069000–0x10106b000 (1672 steps) → VM handler function at 0x100a6f059
  (entered with rcx=0x42) → epilogue at 0x100a708b8/0x100a708d6 (`jmp *%rax`) →
  0x100310f45 → verdict page at TF step 2930.
- The VM's frame slots [rsp+0x328..0x438] hold the fixed stub array (addresses
  + per-name 64-bit constants). [rsp+0x4a8] = 0 (suspicious failed computation).
  Slot values are IDENTICAL between failing runs with different stub bytes —
  they are not hashes of current stub bytes.
- FALSIFIED hypotheses (do not retry): unpatched stubs; probe result values
  (swept c0000005/c0000008/0/c000000d); 32-byte stub tail (wine tail cc-padded
  offline in the dump AND live via the 32-byte patch — verdict still fires).
- The EA-context launcher's environment (extracted from dump 72165) differs
  from standalone mainly by ~35 EA launch vars, and WINEHOMEDIR shows
  `\??\unix\...` (wine's unix namespace) in the EA context vs `\??\Z:\...`
  in older standalone runs — with z:→/Volumes, HOME (/Users/...) is not covered
  by any drive, so wine exposes the unix: namespace in the guest env. A
  suspicious wine signature; consider giving z: a symlink farm that covers
  /Users/gc/Library/Application Support/BF3Mac too, or relocating HOME under
  /Volumes.
- IMPORTANT interpretive caution: standalone "passes" may simply be early exits
  (the launcher exits in ~45–75s standalone) that never reach the late check.
  A truly passing run = the 23:53 one: launcher lived ~7 minutes, spawned the
  service, exited cleanly via its patched ZwTerminateProcess. That run happened
  with Z:→/ and (crucially) while my standalone launcher + its service were
  ALSO running — concurrency may matter. Nobody has yet reproduced a clean
  full-length pass since.

---

## 8. Operational learnings (hard-won)

1. **NEVER enable +relay when EAAC runs**: LdrGetProcedureAddress then returns
   relay thunks and the stub hash fails (a tracing artifact, not a regression).
2. **NEVER enable +module (or any loader-path tracing) on EAAC processes**: the
   launcher crashes at startup ("Exception frame is not in stack limits" during
   unwinding) — a preloader tripwire.
3. **Safe channels for the launcher**: seh, process, service, scm (and file/reg
   on the service exe). The deployed WINEDEBUG spec in the launch env does this.
4. **The dialogs are visible on the Mac screen** — ask the user before trusting
   automated detectors.
5. **EA Desktop self-updates**: it updated 13.805→13.809 overnight, DELETED the
   old version (breaking bin/start-ea.sh's hardcoded path), left garbage
   ("EA Desktop?" dir, a stray file named 13.805.99.0), and the handoff left a
   half-dead UI. /tmp/ea-launch-new.sh targets the new path — update
   start-ea.sh to discover the versioned dir dynamically.
6. **Wine sessions wedge**: after the wedged overnight EA session, NEW wine
   processes hung at startup (even `wine cmd /c echo` produced nothing;
   winspy.exe also hangs there — unresolved whether it's the x87 sidecar attach
   or a busy server). Remedy that worked: kill ALL wine-related processes
   (EADesktop, CEF, launchers, x87sidecar, conhost, wineserver) with -9, verify
   `wine cmd /c 'echo SANITY-OK'` works, then relaunch EA.
7. **The EAAC service** (eaanticheat.gameservice.exe) runs its own dance/probe
  sequence (its own preloader_s.dll) and passes the checks; its own verdict site
  is RVA 0x0046A284. It idles in a message loop after checks and exits
  silently eventually — suspected kernel-driver dependency (eaanticheat.sys is
  absent under wine); nobody has yet traced its silent exit to completion.
8. **Dumps**: every EAAC process run currently writes ~700MB to
   /tmp/eaac-full-<pid>.bin (the TEMPORARY code). Disk had ~112Gi free; prune
   periodically or strip the code when the forensics end.

---

## 9. What to do next (ordered)

1. **Reproduce a clean full-length pass.** With z:→/Volumes and the new EA
   13.809, click Play and just WATCH for 10+ minutes: does the launcher reach
   the SCM phase (svcctl_StartServiceW traces in the wine log), spawn the
   service, and survive? The best observed run did all of that then exited.
   If round-2 fires, you have a fresh failing dump to compare against the
   23:53-era state.
2. **Round-2 predicate decode** (if it still fails): extend the harness TF trace
   to capture memory operands or single-step the 0x100a6f059 handler offline;
   candidate inputs: [rsp+0x4a8] (=0 — find what should write it), the per-name
   constants vs whatever produces the observed side; brute-force slot
   perturbation over [rsp+0x328..0x4a8] via the EAAC_SLOT harness knob is
   cheap and scriptable.
3. **Hide the wine signature in WINEHOMEDIR**: either make z: cover the HOME
   path (e.g. z:→/Volumes plus a second drive letter for
   /Users/gc/Library/Application Support/BF3Mac), or move the runtime home
   under /Volumes so the guest env shows a drive path, not `\??\unix\`.
4. **Trace the EAAC service's silent exit** (suspected driver dependency):
   run it directly with file/reg/seh channels, see what it opens (a
   \Device\... path?) and where it gives up.
5. **Then the game spawn**: the launcher starts the service then (on Windows)
   spawns F1_24.exe — never yet observed here. Presumably gated on the service
   being alive/ready; the service's early exit likely blocks it.
6. **Housekeeping**: strip the TEMPORARY dump blocks from signal_x86_64.c and
   commit the patch-all/32-byte/int29 work (tests are green); update
   start-ea.sh to the 13.809 path; decide on the wine source tree location.

---

## 10. Key numbers cheat sheet

- Verdict sites: launcher RVA 0x0026FA30 (abs 0x10036fa30; INT3 trap), service
  RVA 0x0046A284. Probe stub RVA 0x3059af (abs 0x1004059af); probe sites abs
  0x1004059b1 / 0x100417be6 / 0x1003f5e3f; stage-2 module at 0x100100000
  (0x1793000 in the launcher). Round-2 chain: 0x100a708d6 (`jmp *%rax`) ←
  epilogue 0x100a708b8 ← handler entry 0x100a6f059 (rcx=0x42) ← MBA handler
  0x101069000-0x10106b000.
- Wine stub layout (this fork): 32-byte cells, mov r10,rcx; mov eax,id; test
  [0x7ffe0308],1; jne +3; syscall; ret; then wine tail jmp *[0x7ffe1000].
  KUSER_SHARED_DATA SystemCall=1 (wine sets it). Dispatcher entered via the
  fixed pointer at 0x7ffe1000; the dispatcher subtracts 0xb from frame->rip
  ("Legends of Runeterra hack") — the int29 interception sets frame->rip =
  stub+0x1f so the return lands on the stub's ret.
- The stub list hashed in round 1 (rvas 0x56e30-0x57050): see §3.4.
- Dumps' v4 format: 24-qword header (magic 0xeaacd00000000005, rip, rsp, a90,
  aa0, probe page, 16 GPRs, eflags, cs, preloader base) at offset 0; module at
  192, size 0x1793000; stack 0x5000 at rsp-0x2000; +0x40 a90/aa0; +0x9000
  preloader; then region-walk records [addr,size]+bytes, [0,0]-terminated.
- EA Desktop logs (ProgramData/EA Desktop/Logs) tell the EA-side story:
  "Launching [...]" = click; "Post game cloud sync" = session ended.

---

## 11. Session artifacts inventory

- Git: development branch, HEAD ed6ebe1c693, 4 files dirty (see §5). Two backup
  runtime .so files. All work uncommitted is documented above.
- /tmp: harness, winspy, launch scripts, 3 reference dumps, emu/ tooling.
- /Users/gc/eaac-archive: all old wine-session logs and the capture timeline.
- Scratchpad notes from this session (available on request): eaac-round2-*.md,
  eaac-zdrive-findings.md — the same content is folded into this report.
- EA Desktop 13.809 is currently RUNNING (relaunched 10:21 after the wedge);
  the wine session is fresh and healthy; cron/ps-sampler monitors were stopped.
