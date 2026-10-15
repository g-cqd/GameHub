# EAAC (Javelin) gate-by-gate findings - 2026-10-12/13 capture session
Capture dir: eaac-capture-20261012-231849. Wine trace logs: Hub/Logs/ea-20261012-23*.log.
Runtime: hub-0-winemacfs-dxmtrtv-noWineVer (CoW clone, original untouched).

## Target process flow
EA Desktop -> F1 24 Play -> EAAntiCheat.GameServiceLauncher.exe (game dir) -> preloader_l.dll
PROCESS_ATTACH (via USER32 import chain) runs all env checks BEFORE any SCM/service/driver calls.

## Gate ladder (all at preloader_l.dll, generic error site 00001E83 except gate 5)
1. E111000B "Wine, Proton, and Steam Deck are not supported" - probe of wine-only ntdll
   exports (wine_get_version plaintext in preloader_l.dll), preceded by a deliberate
   DEP-fault/SEH self-decrypt dance at its own entrypoint, plus a manual on-disk mapping
   of ntdll (NtOpenSection/NtMapViewOfSection) re-scanning the export table raw.
   FIX (deployed): renamed wine_get_version/build_id/host_version -> xine_* in the clone's
   ntdll.dll (x64+i386), so both GetProcAddress and the raw-file scan fail cleanly.
2. E1110005 "Windows 7 is not supported" - preloader reads ntdll.dll's VS_VERSION_INFO
   resource via LdrFindResource_U/LdrAccessResource; wine stamps 6.1.7601.24059,
   ProductName "Wine", FileDescription "Wine ntdll".
   FIX (deployed): rebuilt the VERSION resource in both ntdll.dll copies: 10.0.19045.5804,
   "NT Layer DLL", "Microsoft Corporation", "Microsoft(R) Windows(R) Operating System".
   (Version functions RtlGetVersion/GetVersionExW already report 10.0.19045 via the
   per-exe AppDefaults "Version"="win10" set for the 5 EAAC/game exes; registry
   CurrentVersion values were already Win10.)
3. (My packing bug produced E1110009 "Windows 10 Beta" mid-gate: dwFileVersionLS must
   be (build<<16)|UBR = 0x4A6516AC, I initially wrote it transposed -> build 5804 looked
   like a Win10 Technical Preview build. Corrected.)
4. PASSED after the above: preloader proceeded further into init.
5. E111000D @ 0026FA30 "Conflicting software detected!" - EAAC's second-stage image
   (24 MB, mapped RWX at 0x100100000) executes a RAW Windows syscall:
     seh:sigsys_handler SIGSYS, rax 0xfa, rip 0x1004059b1
   Windows 10 19045 x64 syscall 0xFA = NtGetNlsSectionPtr (j00ru table; neighbors
   0xF9 NtGetNextThread, 0xFB NtGetNotificationResourceManager). Args at the syscall:
   r10=-1 (Windows stub ABI: arg1 in r10), rdx=stack ptr, r8/r9 garbage-ish -> probe
   call with invalid args. On real Windows: clean NTSTATUS (STATUS_INVALID_PARAMETER
   class). Under wine: SIGSYS -> sigsys_handler redirects ANY syscall into wine's
   dispatcher -> wine syscall #250 (wrong function) -> faults -> handle_syscall_fault
   returns c0000005 as the "syscall result" -> EAAC reads tampering.

## Why gate 5 needs a wine-fork patch (no registry/PE trick can fix it)
dlls/ntdll/unix/signal_x86_64.c (their fork, CW hacks): sigsys_handler currently treats
every SIGSYS as if it came from wine's own __wine_syscall_dispatcher (rip+0xb resume,
frame->rax = the number, dispatch into wine's syscall table). Foreign syscalls must be
detected (rip outside wine's dispatcher/stubs) and emulated:
  - minimal V1: return STATUS_INVALID_PARAMETER (0xC000000D) class NTSTATUS in rax,
    rcx = rip+2 (Windows clobbers rcx with return addr), r11 = eflags, rip += 2.
  - full V2: table of Windows syscall numbers for the target build (19045, generated
    from j00ru/windows-syscalls CSV) -> wine syscall stub for the same Nt function
    (extract wine's index from the PE stub's `mov eax, imm32`) -> re-dispatch through
    __wine_syscall_dispatcher with frame args fixed for the Windows ABI
    (frame->rcx = r10; stack args identical at [rsp]/[rsp+8]).
Wine implements NtGetNlsSectionPtr (ntdll.spec:243, -syscall) so V2 can service it
natively. Build: src/wine/build-macos-x86_64.sh (configure + make dlls/ntdll), then
swap ntdll.so/ntdll.dll into the runtime clone.

## Evidence captured
- Full relay traces of every gate decision (launcher threads in ea-2026101*.log).
- dropped/: copies + sha256 of GameService.exe/.dll, preloader_l/_s.dll, sonarinst.exe
  (NSIS installer, EA "Sonar" component, 1.78 MB, dropped in Temp during EA start),
  plus every EA/AC file.
- process/file/net timelines from poller.sh (still running).
- ShowCrashDialog=0 was set for clean capture (backup: Backups/user.reg.pre-eaac-capture-20261012).

## Environment fixes in prefix (reversible)
- AppDefaults Version=win10 for: EAAntiCheat.GameService{,Launcher}.exe, Installer.exe,
  F1_24.exe, F1_24_Trial.exe (+ cmd.exe for testing).

## Next steps
1. Implement foreign-syscall emulation in the fork (V1 minimal, V2 full table).
2. Rebuild ntdll, deploy to -noWineVer clone, restart EA, click Play.
3. Expect more syscall-based gates (process enumeration etc.) -> V2 pays off.
4. PunkBuster note: PnkBstrA.exe (from BF3/BF4) auto-runs in the prefix; if a later
   gate does real process enumeration, disable its service (Start=4) for F1 24 runs.

## Session 2 (2026-10-13 00:00-01:00): raw-syscall emulation landed + gate 5 anatomy
Commits on wine fork development branch (all with regression tests, TDD):
- cea1c0dd1fa ntdll: Emulate raw Windows syscalls executed by native code on macOS
  (sigsys_handler foreign-syscall branch, 19045 syscall table from j00ru data,
  unix/winsyscall.c, test dlls/ntdll/tests/syscall.c)
- 0814ee265b4 ntdll: Record the ntdll mapping in the loader (tamper-proof base)
- a0017eaee81 ntdll: Resolve the table before guest code can patch the stubs
  (EAAC preloader hooks ntdll stubs before its first syscall - lazy scan saw patched stubs)
- aabb80c26c8 ntdll: STATUS_INVALID_PARAMETER for unknown NLS section type
  (wine returned STATUS_INVALID_PARAMETER_1; EAAC compares exact statuses)
- 024031195ba ntdll: syscall table index = stub-imm32 + 1 (0-based stub ids vs 1-based
  dispatch table; two accidental off-by-ones cancelled; now correct + verified at load
  against KeServiceDescriptorTable in the trace)

State of gate 5 (E111000D "conflicting software", site 0026FA30):
- The probe: EAAC's stage-2 module (24MB, mapped RWX at 0x100100000, obfuscated VM)
  executes a RANDOMIZED raw syscall (0xfa NtGetNlsSectionPtr this session, 0x4
  NtWaitForSingleObject in others) with garbage args, with custom EFLAGS set via
  pushfq/popfq, then saves {rax, rcx, r11, post-flags} and jumps to an MBA-obfuscated
  VM handler (0x1010698c6) that hashes the tuple and dispatches via jmp *rax.
  Mismatch => "Conflicting software detected".
- Our emulation now returns: correct function (id 0x9b -> NtGetNlsSectionPtr),
  correct status (c000000d), rcx = return address (rip), r11 = pre-syscall flags,
  post-flags = pre-flags. All individually Windows-correct.
- Verdict still trips => the divergence is inside the hash inputs (subtle flag or
  arg difference) or the handler expects a different tuple entirely.
- Memory dumps of the stage-2 module captured via a temporary in-handler dump
  (probe site, comparison handler, verdict site, VM return area, PE headers):
  dropped/eaac-stage2-64771.bin (first dump), dropped/eaac-stage2-71587.bin
  (with comparison region). Probe stub at dump+0x1fbb; comparison handler at
  0x1010698c6 (dump2 offset 0x58c6); verdict builder near RVA 0x26fa30.

Next steps for gate 5:
1. Reverse the MBA comparison handler (dump2) to extract the expected tuple/hash.
2. Cross-check: capture the same probe's tuple on a real Windows 10 19045 machine
   (run the launcher there with a debugger) and diff against ours.
3. Candidate divergences to inspect first: (a) EFLAGS masking differences
   (Rosetta's flag model vs real HW for the popfq'd value), (b) arg5/stack
   contents at rsp+0x28, (c) the exact NtGetNlsSectionPtr behavior for the
   probe's specific garbage args on real Windows.

Follow-ups (noted, not done):
- wine_get_* export renames are binary patches in the runtime clone only; wine's
  own shell32/setupapi import wine_get_host_version by name (fresh-prefix init
  crashed on a test prefix). Source-level rename + full rebuild needed before
  this can be committed properly.
- The kernel-idle exception suite (ntdll_test exception) never completed under
  Rosetta (ran >20 min); worth a background run before any upstream push.

## Session 3 (2026-10-13 01:00-01:30): gate-5 inputs identified
- Probe env var identified: PACKER_CRASH_AT (VMProtect crash-debug var; not-set is normal on Windows too, so this query is fine).
- Flag semantics verified: IF/DF/AC all round-trip correctly through the emulation (regression test added; commit 024031195ba-era + new).
- Stack dump at SIGSYS (dropped/eaac-stage3-95786.bin): comparison handler inputs are
  [rsp+0x98] = per-run hash constant (0xf74875b90811a644), [rsp+0xa0] = a WINE NTDLL CODE
  ADDRESS (RVA 0xccb4 in the run's ntdll), [rsp+0x120] = stage-2 module base.
  The two ntdll addresses (0x18 apart, RVAs 0xcc9c/0xccb4) were resolved by the module
  earlier via LdrGetProcedureAddress and are ordinary ntdll code bodies.
- STRUCTURAL FINDING: the gate-5 hash blends wine ntdll code addresses into the VM
  dispatch. On Windows these point at Windows ntdll code. Any code-content or
  pointer-relationship check on them cannot match wine's implementation.
- Next phase for gate 5 requires reversing the MBA comparison handler (dumps archived)
  to learn exactly what it does with the two addresses. If it checksums their code
  bytes, the answer is not emulation - it is making the checked bytes match, which
  for arbitrary function bodies means the check is out of reach of a compat layer
  without a much deeper strategy.
Commits this session: 618204df4f3 (RtlQueryEnvironmentVariable trace; also useful upstream).
