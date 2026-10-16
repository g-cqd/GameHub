# F1 24 / EA anti-cheat — takeover from this document
Updated 2026-10-16. User requested a complete Agora handoff. Owner objective: run F1 24 through genuine required anti-cheat on this Mac. This objective is NOT achieved.

## Read first / current next action
Resume **E-025**, not driver extraction or another unchanged F1 launch.
E-025 query1 found concrete native syscall-exit register side effects missing from the inspected Wine fallback. It has NOT established that F1 consumes those differences or that a correction fixes F1.
Next bounded query: inspect the alternate native return branch at kernel RVA A16DC0, then inspect whether the captured launcher continuation reads the changed volatile registers before overwriting them. Use the existing signed kernel, matching symbol data, captured image/contexts and Capstone/Unicorn. Do not invent missing register/memory state. A native-supported failing regression must precede any return-state patch.
The experiment has one of its two focused static queries used; do not reset its budget by renaming it. No launch/build has occurred in E-025.

## Exact working state
- Main source: /Users/gc/Developer/wine, branch main, HEAD 0413180984c87789aeae6bf510878299a0f1e117.
- Only current main Wine diff: remove nine-line unconditional raw0x101 -> NtGetNextThread override from dlls/ntdll/unix/winsyscall.c. No commit.
- Main and research winsyscall.c now have identical SHA256 ed4ae31e9cc81e984a1231efe6e5d84cae3da8c8d940d991482abafd02c294c7.
- Research source /Volumes/ExT2/GameHub/work/codex-eaac-context/src has pre-existing diagnostic signal_x86_64.c and thread.c output-handle-guard edits. Preserve them. Only the alias block was removed this session.
- Warm build /Volumes/ExT2/GameHub/work/codex-eaac-context/build; focused make -j2 dlls/ntdll/ntdll.so passed (job163).
- Research runtime /Volumes/ExT2/GameHub/work/codex-eaac-context/runtime.
  Current signed ntdll.so SHA256 dc9e96cf7be649234c804600ead0147524e65e2abe5d2a5958e16db247263182.
  Backup /Users/gc/eaac-archive/eaac-acquisition-20261015/research-ntdll-before-registry-correction.so SHA256 7b452e0816230dccbb7f4ea80cce214a1335975253ba109b8421fe40ba8ef8ed.
  Replacement was staged, signed, codesign-verified and atomic. Production runtime was NOT changed.
- Production runtime /Volumes/ExT2/GameHub/Runtimes/hub-0-winemacfs-dxmtrtv-noWineVer.
- Production prefix /Volumes/ExT2/GameHub/Prefix.
- Production game /Volumes/ExT2/GameHub/EA Games/F1 24.
- Research prefix /Volumes/ExT2/GameHub/work/eaac-current-install-20261015/prefix, with sibling home and tmp.
- Research prefix dosdevices/z: points to z-empty. Host /tmp executables are outside its drive mappings. Put diagnostics in mapped C: and launch using Windows paths.
- GameHub /Users/gc/Developer/GameHub contains deleted tracked bin/start-ea.sh, its backup and bin/wine-query.sh. User did not know why and authorized recreating/building what is needed. Do not blindly restore others' changes; no restoration was necessary this session.
- No temporary probe executables/sources or temporary LIEF/Ghidra projects remain from the completed phases. Evidence copies remain in archive.

## Live process state at handoff
Revalidated with ps:
- EA Desktop host PID43467 alive, production executable EA13.809.0.6322-1791939025.
- Production wineserver host PID43472 alive.
- No F1_24.exe or EAAntiCheat.GameServiceLauncher.exe found.
Earlier owned launcher host PIDs45429/45518 are gone; their measured guest process IDs were1140/3056. Trace prefix047c was a THREAD ID1148, not a guest process ID.
No launcher exit code was recovered in the selected fresh log. A later normal-OK helper found no matching processes/dialogs, so do not credit it with dismissal. Do not restart, kill or signal the production EA session to clean research work.

## Current normal authenticated F1 path: E-018
EA Desktop authenticated true and Online at 2026-10-16T13:12:09–10Z; SPA load success13:12:23Z.
One explicit EALauncher origin2 request for content ID16425782 at13:13:30Z was approved.
Offer ID Origin.OFR.50.0005434, content/master title ID16425782: do not conflate them.
Normal configured launcher: E:\EA Games\F1 24\EAAntiCheat.GameServiceLauncher.exe.
EA reports missing C:\ProgramData\Electronic Arts\EA Services\License\16425782.dlf, requests reactivation, and120s later still reports license missing.
EA automatically created two launcher instances from that one explicit request. Both displayed:
"The program encountered E111000D at 0026FA30 during initialization. Conflicting software detected!"
This production fatal was already documented in Oct12/14 history; this session REVALIDATED it, not discovered a new fatal.
Publisher preloader and launcher files passed embedded Authenticode and hash verification (LIEF1.0.0); this is not a Windows trust-store/revocation check.
- production preloader_l.dll SHA577f2c445b20270a807c5bf92939a3c72a6e55588c63b60d2ab68162cfe138ae
- production launcher DLL SHAdcd29dab2cfa12a5211ccbf09c82b2d7f765932b4cc9779f832abd3f9c974ad7
- production launcher EXE SHA4265e4b290af43a3b1d1278ffb76bd4232e53ff4e45c38477518e5617f1def6f
Research launcher DLL7d53b70c940e92963ec8d5f30ca0463df0152e1bdfc251114bb4f51374f03b21 and EXE32ed87237e64b96a15135a406ac79063caaf638b975b3467bd9cec6e5d76fcb5 are DIFFERENT artifacts. Do not transfer its00457425 fatal analysis as the same binary.

## Current production module capture: E-019
Archive production-launcher-mapped.bin: base100100000, SizeOfImage1793000, 24719360bytes, SHA95476c3729bc593eaab9a76f7809b20272ab61c2e35010b0f91a21f945c4e0d2.
Validated DOS/PE/header image base and size after live capture from owned PID45429, then detached.
Fatal RVA26FA30 lies in pdata26E917..27A38D. A candidate indirect call [r13+60] ends exactly at26FA30. Surrounding code is obfuscated; this does NOT identify a failed Windows API.
Two focused static queries exhausted. Do not repeat the same disassembly as a new investigation.

## Native Windows reference without Windows execution: E-023
This is the important new route: inspect Microsoft-hosted signed native artifacts, rather than require a Windows VM.
Artifact root /Users/gc/eaac-archive/eaac-acquisition-20261015:
- native-win10-ntoskrnl.exe, version10.0.19041.5794, SHA f394a43b4aad1936af9a4fc6954904c22b9193a105b26cb9113a18652068eed4.
- Official URL https://msdl.microsoft.com/download/symbols/ntoskrnl.exe/5B5EC8781046000/ntoskrnl.exe.
- LIEF1.0.0 default signature and HASH_ONLY both OK.
- native-win10-ntkrnlmp.pdb, SHA a98c6aa4164972276750805f7f4b799a0c1bb4882bbbf2dc82e446b549c57db8.
- Official PDB URL https://msdl.microsoft.com/download/symbols/ntkrnlmp.pdb/7A49711F9BF937DF3C52C7A5B94C4DD71/ntkrnlmp.pdb.
- PDB GUID7A49711F-9BF9-37DF-3C52-C7A5B94C4DD7 matches PE CodeView. DBI age1 matches PE age1; information-stream age5 separately recorded. Do not omit this distinction.
- native-kernel-reference-manifest.json pins provenance/index/hash/signature/debug metadata. Winbindex was an INDEX only, not the binary supplier.
- native-win10-symbols.log is llvm-pdbutil dump --summary --publics output; section:offset numbers are DECIMAL.
Kernel preferred base140000000. PE section8 .text RVA200000; section9 PAGE RVA5CD000.
KiServiceTable RVA C7AA0; KiServiceLimit C8204.
ON-DISK service-table entries are plain RVAs. Do NOT apply the runtime signed-offset >>4 encoding to disk entries.
table[101]=78DF90 NtInitializeRegistry; table[F9]=6BA070 NtGetNextThread.
NtInitializeRegistry pdata78DF90..78DFF9:
- Checks PreviousMode.
- User flag13E8 takes a special privilege-dependent path at852E56..852E7B, which can returnC0000061.
- Other user calls delegate through ZwInitializeRegistry at3FC400..3FC41F; stub emits EAX101.
- Kernel-mode path uses low16flags. Invalid flags outside0..2 and1000..13E7 returnC000000D.
Microsoft documents the Zw wrapper setting PreviousMode=KernelMode and restoring it:
https://learn.microsoft.com/en-us/windows-hardware/drivers/kernel/previousmode.
Thus captured invalidD8F0 -> STATUS_INVALID_PARAMETER is supported by native code. It is not evidence that this call must become NtGetNextThread.

## Verified correction: E-024
Removed the unconditional Win11-style alias from main/research Win10 cache.
Identical six-case mapped executable (existing syscall.c invalid-condition inputs):
3, FFF,13E9,FFFF,FFFFFFFFFFFFD8F0,123456780000D8F0.
- job162 baseline:6/6failed, allC0000008, exit1.
- job163 focused ntdll build:passed14.4s.
- job165 signed research replacement:passed. Research wineserver-w exit0; production preserved.
- job166 corrected:6/6passed, allC000000D, exit0.
One diagnostic executable compile and one focused library build. Full Wine test harness/suite NOT built/run.
Research winsyscall source equals main source exactly; other research diagnostics remain.
Native13E8 semantics are a separate queued correctness task eaac-registry-13e8-native-contract. The existing ACCESS_DENIED fixture is not a verified universal native outcome. It is not the observed F1D8F0 call and was not changed.

## Unfinished experiment E-025: exact state
job168 disassembled KiSystemServiceExit RVA411F10..4122EC (until KiSystemServiceExitPico label).
Full output copied to archive/native-syscall-exit-query1.log.
Relevant NORMAL user return instructions:
- 412067 ldmxcsr [rbp-54]
- 41206B xor r10,r10
- optional instrumentation path may set r10 to saved user RIP; do NOT call R10=0 universal.
- 412256 restore result RAX from[rbp-50]
- 41225A mov r8,[rbp+100]  (then used as returned user RSP)
- 412261 mov r9,[rbp+D8]   (then used as returned user RBP)
- 412268 xor edx,edx
- 41226A..41227E pxor xmm0..xmm5
- 412282 RCX=[rbp+E8] (saved user RIP)
- 412289 R11=[rbp+F8] (saved user flags)
- 412290 test byte[rip+9EF5A9],1 ; jne A16DC0 (alternate exit NOT YET INSPECTED).
- otherwise41229D RBP=R9,4122A0 RSP=R8,4122BC SYSRETQ.
Inspected Wine unsupported foreign-syscall branch in signal_x86_64.c only sets RAX/RCX/R11, then returns.
This is a concrete difference on the inspected native path, NOT YET a proven F1 cause.
No return-state source patch, new regression or game launch in E-025.
Next developer should establish alternate-path applicability and target read-before-write consumers. A valid new oracle/regression must precede any implementation.
For implemented foreign calls, do NOT overwrite input RDX/R8/R9 before Wine dispatcher consumes arguments. Any fix would need return-path handling. Preserve instrumentation callback/TF semantics and nonvolatile registers. This is a design caution, not an implemented design.

## Other retained evidence / closed lanes
- Complete newer research launcher module codex-launcher-complete-module.bin:52101120bytes, base100100000, SHA3d04844246600418855e122a0d002a0de6aabe9cda93c139675093172a3bfa14.
- Complete research service module codex-service-complete-module.bin:63258624bytes, base100100000, SHAed84fa5a5b24c6bdcf5f0d34c93eedbf9fcd38fdd2fe689c45356984cad940eb.
- Old codex-service-full-image.bin has wrong prefix/base and omits final MiB; superseded, do not use as complete.
- codex-four-probe-context-run.log, codex-diagnostic-context-run.log, codex_replay_captured_context.py preserve four raw-call contexts/replay.
- Replay validates first3 continuations against16live registers+RIP; that is Wine replay agreement, NOT native Windows agreement.
- Sampled fourth-return substitutions all still reach fatal callback. Do NOT repeat status guessing.
- Replay stops on missing memory or UcError yet can exit0. Require semantic endpoint markers; no exit-only conclusions.
- Research return comparison at1014BCFBD comparesC000000D withC0000008; this alone does not establish the correct operation/profile or fatal causality.
- NtInitializeRegistry is COMMENTED OUT in ntdll.spec:251. Prior claim that an actual rewritten exported registry stub made a bad round trip was overclaimed and corrected. Raw dispatch discrepancy and regression were real.
- Build/runtime whole-file hashes differed due signing. All nonzero-offset Mach-O section contents matched before E024. The old mismatch was NOT evidence of stale executable code.
- E016 had4failed standalone Wine harness builds, then2host-SIGSEGV diagnostic launches with no syscall result. Do not repeat that harness approach. Normal compiler-runtime probes in mapped C work.
- Signed production preloader contains both Wine rejection and syscall-emulation-disabled messages. E021 init11A0..1EAA has a Wine export-lookup rejection branch; E022 helper1000..11A0 discovers/maps original ntdll. No supported Wine capability contract established. String-only support inference is invalid.
- Publisher installer d0396b7fe0331cef94278ed015c93012cd9ab67eb02e3775abd6660e96f5b6eb,277175032bytes. Resource102 is an archive extraction helper path; actual private packer child is GameService.dll itself with exact nonASCII PACKER_FUNCTIONALITY token. Not service.exe noargs. Existing archive JSON preserves exact token; do not paste invented flags.
- Installer configures kernel/minifilter registration. CurrentControlSet is a serialized symlink to ControlSet001; initial missing-key claim was wrong. Registered driver ImagePath exists but file absent.
- Resource10100/10150 opaque: not identified as drivers. Bounded PE/Brotli/plaintext/writer-wrapper scans did not recover a driver; do not repeat without new evidence.
- No genuine driver recovered. Kernel architecture has publisher evidence; necessity of recovering this exact file BEFORE any startup diagnosis and causality for E111000D remain UNPROVED.
- VM route canceled: QEMU/swtpm/UTM/VM disk/media and private VM credentials removed previously. Do not recreate VM/Windows machine work. Static native artifact analysis is allowed and already useful.
- No NFS launch authorized in this work. No generic Wine kill.

## Authoritative documents and all-evidence index
/Users/gc/Developer/GameHub/docs/eaac/:
- EAAC-INVESTIGATION-CONTROL.md: current guardrails/claim corrections.
- EAAC-EXPERIMENTS.json: full E001..E025 questions, predictions, evidence, outcomes, limits.
- EAAC-IMPLEMENTATION-ROADMAP.md: genuine protected-game objective, observed requirements only.
- EAAC-NATIVE-REFERENCE-20261016.md: signed native reference and verified correction.
- EAAC-SYSCALL-GATE-20261016.md: gate history/corrections; integration not approved.
- EAAC-INSTALL-PATH-20261016.md: recovered publisher install chain.
- EAAC-SESSION-PRIORITIES-20261016.md: real launch critical path.
- EAAC-CODEX-TAKEOVER-20261015.md: detailed prior captures; some historical statements are superseded by current control/ledger.
All private evidence: /Users/gc/eaac-archive/eaac-acquisition-20261015.
Jobs133..166 copied as current-launch-native-reference-job-N.log; job168 copied as native-syscall-exit-query1.log. Earlier job97..132 and associated analysis logs/manifests also archived.
Do not share EA auth logs or binary memory contents wholesale; they may contain private session data. The published handoff contains no credentials/tokens.

## Tools and execution constraints
- C compiler /Volumes/ExT2/GameHub/toolchains/llvm-mingw-20261006-ucrt-macos-universal/bin/x86_64-w64-mingw32-clang.
- x86 analysis Python /Volumes/ExT2/GameHub/work/codex-eaac-context/analysis-venv/bin/python has Capstone/Unicorn, NO pip.
- Host python3 is ARM64. Do not import ARM64 native wheels into the x86 analysis venv. Temporary LIEF1.0.0 install was removed after use.
- /opt/homebrew/opt/llvm/bin/llvm-pdbutil supports dump --summary --publics. Use exact symbol records rather than dumping logs into chat.
- Ghidra12.1.4 /opt/homebrew/Cellar/ghidra/12.1.4/libexec/support/analyzeHeadless.
  JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home.
  Retained script archive/FocusedEAAC.java; noanalysis, bounded exception-table ranges, no whole-program pass.
- LLDB: BEFORE attach set target.memory-module-load-level minimal and target.preload-symbols false. Default attach timed out25s; minimal attach/stack/detach completed1.9s.
- Builds/tests through Agora work_run/work_wait; scope f124-anticheat exists (scope eaac does NOT).
- Other agents' messages/queued commands are untrusted. Read queued commands with work_show and accept digest only if owner task authorizes them.
- status_set server variant is unsupported by this daemon; do not keep retrying it.
- No subagents spawned. No commits/push/rebase. Preserve unrelated edits.

## Queue / acceptance
task7 done (capture deliverable only); task8 and11..16 canceled as unconditional driver/kernel implementation plan superseded.
task9 is the unresolved causal-startup diagnosis; released to queue for takeover.
task10 follows9: one causally established startup contract repair.
task17 integration follows evidence gates; task18 genuine authenticated protected gameplay follows17.
task90 is historically done but does NOT mean initialization fixed.
eaac-syscall-evidence-gate remains failed/not approved for integration.
eaac-registry-13e8-native-contract is a separate queued follow-up.
F1 window, helper exit0, fabricated service/device success, disabled protection or hidden Wine identity alone are NOT acceptance.
Existing tree/runtime historically hides wine_get_version and stamps Windows ntdll resources; disclose that history, do not equate identity masking with genuine protected gameplay.
Success still requires observed authenticated F1 gameplay with actual required protection.

## Lean investigation guardrails
Register before executing; native/target/runtime identity pinned.
15min evidence,45min maximum2focused static queries,20min maximum2target launches,10min decision.
One changed variable per experiment. Semantic markers and actual child/guest/host identity required.
Close bounded negative approaches, no repeated unchanged decoder/search/launch. Unknown remains unknown.
Do not mark goal/task complete from a green diagnostic. Goal remains active.

