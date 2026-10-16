# Syscall profile gate — failed, 2026-10-16

At Wine revision 0413180984c, the generated Win10 table assigns 0x101 to
NtInitializeRegistry (dlls/ntdll/unix/win10_19045_syscalls.h:283).
eaac_patch_windows_zw_stubs passes that same table to the stub encoder
(winsyscall.c:410), but load_windows_syscall_cache then replaces dispatch entry
0x101 with NtGetNextThread (winsyscall.c:243). Both the patched int-2e path
(signal_x86_64.c:3205) and foreign SIGSYS path (signal_x86_64.c:3672) use that map.

Correction after checking ntdll.spec: NtInitializeRegistry is commented out
at line 251. An actual emitted NtInitializeRegistry stub has not been established.
The table and unconditional raw-dispatch override disagree, but this does not
prove an affected stub round trip or the cause of E111000D.

E-016 did not establish the behavioral regression. Four standalone harness build
attempts failed; a separate diagnostic probe compiled but both launches exited
with host SIGSEGV (-11), without recorded syscall results. No correction was
applied. The research build and installed runtime ntdll.so hashes differ, so
binary equivalence is unverified. The two-launch budget is exhausted.

The correct EAAC foreign-call profile is unresolved. Advancement after a targeted
mapping change does not establish how the target selected its syscall number.
The next fatal predicate is also unresolved; task90-test2.log:4311 still reports
E111000D. The output-handle change in thread.c is logically separate and needs
its own behavioral validation rather than being accepted through the mapping test.

Deployment remains blocked. A repair must distinguish foreign-call profile
selection from Wine stub round trips, prove producer/consumer identity for the
selected table, and preserve known calls in the Win10 profile. Do not replace the
Win10 table with guessed individual Win11 numbers. No code was changed in this gate.
Integration task-17 depends on eaac-syscall-evidence-gate; failure must not be
converted into done merely because this review has completed.

E-017 update: every nonzero-offset Mach-O section matches between build and
installed runtime, including executable code. Whole-file hash mismatch alone is
not evidence of stale code. A diagnostic placed inside mapped C: reaches main,
raw 0x101 dispatches to Wine id0x9a and returns STATUS_INVALID_HANDLE for argument3.
The old /tmp path was outside the isolated drive mappings. Exact host SIGSEGV
cause remains unproven because the new probe also reduces inputs and adds markers.
This result establishes raw dispatch behavior, not E111000D causality.

E-023/E-024 update: direct Microsoft-signed Windows10 kernel analysis supports
STATUS_INVALID_PARAMETER for the captured low16 flagD8F0. The unconditional
NtGetNextThread override was removed from main and the research source. Identical
six-case regression executable failed all6cases before correction and passes all6
afterward. Focused research ntdll build passed; production runtime unchanged.
Full Wine suite was not run. EAAC foreign-profile selection and F1 fatal causality
remain unresolved; this does not approve protected-game integration.

Native flag13e8 has a separate user-mode privilege-dependent path and can return
STATUS_PRIVILEGE_NOT_HELD. Existing blanket ACCESS_DENIED fixture is tracked by
Agora task eaac-registry-13e8-native-contract; no unrelated status patch was made.
