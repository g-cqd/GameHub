> Superseded — see docs/eaac/ for the current version.
# EAAC (Javelin) compatibility layer — status report

Date: 2026-10-14 01:25 (round-2 decode in progress; supersedes the 00:25 report)
Target: run EA Javelin-protected games (F1 24, BF1) under Wine on Apple Silicon (M2 Pro, macOS 27.2, Rosetta 2)
Wine fork: g-cqd/wine, branch `development`, tree at /Volumes/ExT2/GameHub/src/wine
Runtime: /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer
Launch: /Volumes/ExT2/GameHub/bin/start-ea.sh (HUB_RUNTIME + HUB_WINEDEBUG)

## 1. Where we are

The EAAC launcher (and the EAAC service exe) pass their FIRST verification round
thanks to the Zw stub patch (commit ed6ebe1c693, later upgraded to patch all 257
resolvable stubs — uncommitted, TDD-green 33/33). But a SECOND verification round,
seconds after the syscall probes, still fires E111000D ("Conflicting software
detected!") — shown in a MODAL DIALOG on the wine desktop that is INVISIBLE
(behind the EA Desktop window). The process then sits in the dialog's message
loop (what looked like "idle" in stack samples). EA Desktop treats
GameServiceLauncher.exe as the game's exe, so while the dialog is up the game
never starts. That is the "game is not starting" symptom, fully reproduced and
understood mechanically. Round 2's predicate is the current work.

## 2. What round 2 is NOT (all live-tested)

- Not unpatched Zw stub bytes: patching all 257 resolvable stubs did not clear it.
- Not a wait/timeout for the anticheat service: the verdict fires within ~15s;
  the service exe (EAAntiCheat.GameService.exe) fails its own round 2 the same way
  (verdict RVA 0x0046A284 in its module; the launcher's is 0x0026FA30).
- Not the probe syscall results (replay perturbations never flip anything).
- Not a proton/wine detection path: this Sep-2024 EAAC build has no
  proton/steam markers in the preloaders; the wine check is absolute — we hide
  wine_get_version (commit 85195944d91), so the launcher walks the full Windows
  path, which is why the driver/service-dependent flow matters at all.

## 3. Round-2 decode (latest findings — resume here)

The harness reproduces the round-2 verdict offline from /tmp/eaac-full-56046.bin
(7065 TF steps). The argument-enriched trace (/tmp/emu/r2-trace2.bin, 48-byte
records rip/rsp/rcx/rdx/r8/r9) decodes the flow:

- probe stub 0x1004059af -> MBA handler 0x101069xxx (1672 steps) -> VM handler
  function 0x100a6f059 (entered with rcx=0x42, r8=0x281f4c72) -> epilogue
  `addq $1,%rax` at 0x100a708b8 -> `jmpq *rax` at 0x100a708d6 -> 0x100310f45 ->
  verdict page 0x10036f000 at step 2930. Post-verdict steps are dialog building
  (memset 8KB, _vsnwprintf with E111000D args).
- The VM stores a FIXED consecutive array of ntdll Zw stub addresses in frame
  slots [rsp+0x328..0x438] with interleaved 64-bit per-name values:
  ZwSetInformationKey/Token/VirtualMemory/IntervalProfile/IoCompletion/
  IoCompletionEx/SystemInformation/SystemTime/ThreadExecutionState/SuspendProcess/
  SystemDebugControl (rvas 0x56e30..0x57050). The "random names" theory is dead —
  the old six were just the first six of this fixed list.
- The interleaved 64-bit values are IDENTICAL across builds with different stub
  bytes (six-stub vs 257-stub) and differ only in the relay-era dump (different
  names resolved): they are per-name constants, not hashes of current bytes.

FALSIFIED this session (do not retry):
- unpatched stubs (patch-all-257 live) — still E111000D.
- probe result values (replay sweep c0000005/c0000008/0/c000000d) — no effect.
- 32-byte stub window with wine tail (cc-padded all 257 stubs offline; live
  32-byte patch with cc padding) — verdict still fires. (Caveat: verify real
  19045 padding bytes if this angle returns.)

Live leads:
- [rsp+0x4a8] = 0 in the dump — a suspicious input slot (a failed computation?).
- Counts [rsp+0x408]=0x102, [rsp+0x3a0]=0x206 in the frame.

Next steps (priority): (1) decode the MBA at 0x100a6f059 — especially where the
observed side of the comparison comes from; brute-force slot perturbation via
the harness EAAC_SLOT knob over [0x328..0x4a8] is cheap and scriptable;
(2) find what writes [rsp+0x4a8]; (3) after a passing replay, strip the TEMPORARY
dump code, commit, redeploy, full-flow test. Details: scratchpad files
eaac-round2-forensics.md and eaac-round2-checkpoint2.md.

## 4. Fixes already landed this session (all live-verified)

- Commit ed6ebe1c693: gate-5 round-1 fix (name-resolved stub patch at the
  dance), generalized dance trigger (execute fault on readable non-exec page),
  int 0x29 interception (patched stubs + KUSER_SHARED_DATA SystemCall flag=1
  would otherwise fastfail ANY caller — the game calling
  ZwSetThreadExecutionState would crash with STATUS_STACK_BUFFER_OVERRUN),
  sigsys translation, export-table off-by-one fix in the stub lookup
  (AddressOfNameOrdinals are direct indices; the old -Base/+1 silently
  mis-dispatched foreign probes for non-consecutive stubs like ZwTraceEvent).
- Uncommitted on top: patch-all-257 (winsyscall.c eaac_patch_windows_zw_stubs +
  registry), tests extended to 33 (ZwTraceEvent 0x5e, ZwUnloadDriver 0x1c8
  included). virtual suite 2335/2335, exception suite baseline-identical.
- Probes now dispatch CORRECTLY (e.g. nr 0x4 = NtWaitForSingleObject -> wine id
  4; the old code's 0x1b was a wrong function). nr 0x101 = NtInitializeRegistry
  (no wine stub) -> STATUS_INVALID_SYSTEM_SERVICE; the loader accepts it.

## 5. Operational notes

- NEVER use +module (or any loader-path tracing) on EAAC processes: the
  launcher crashes at startup with an unwinding error (preloader tripwire).
  Safe channels: seh,process,service,scm,reg,file (reg/file verified on the
  service exe).
- NEVER use +relay: relay thunks break the stub hash (known artifact).
- Detect hidden EAAC dialogs: /tmp/winspy.exe (EnumWindows dump; source
  /tmp/winspy.c, build with the tree's llvm-mingw toolchain). An 'Error' dialog
  with class #32770 owned by the launcher/service pid = E111000D is up.
- EA Desktop logs: drive_c/ProgramData/EA Desktop/Logs/ (EADesktopVerbose.log
  shows "Launching [E:\EA Games\F1 24\EAAntiCheat.GameServiceLauncher.exe]" —
  EA Desktop treats the launcher AS the game exe; it believes the launch
  succeeded and just monitors).
- The deployed runtime ntdll.so currently writes one ~577MB dump per EAAC
  process run (/tmp/eaac-full-<pid>.bin) — temporary, needed for round-2
  analysis; strip before shipping.
- Backups: ntdll.so.bak-20261013-prod (six-stub build), .bak-20261013-regs,
  .orig-aot; PE ntdll.dll untouched tonight (ntdll.dll.bak-20261013-prod).

## 6. Key numbers cheat sheet (updated)

- Verdict sites: launcher 0x0026FA30 (abs 0x10036fa30), service 0x0046A284.
- Probe stub RVA 0x3059af (abs 0x1004059af); stage-2 module @0x100100000.
- Probes observed: nr 0x4 (NtWaitForSingleObject) x3, nr 0x101
  (NtInitializeRegistry); service: same nr 0x4 x3 at other sites + 0x101.
- Round-2 trace hot ntdll rvas: 0x591f0 (memcpy_s, 255 calls), 0x69270, 0x42950.
- Round-2 branch chain: 0x100a708d6 -> 0x100310f45 -> 0x10036f8fa (verdict page).


