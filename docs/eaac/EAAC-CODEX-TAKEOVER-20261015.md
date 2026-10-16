# EAAC investigation: verified takeover findings

Historical report. For current status, corrections and mandatory experiment gates,
read [investigation control](EAAC-INVESTIGATION-CONTROL.md). The later task-90 commit
advanced execution but did not eliminate initialization failure. Windows is cancelled.

Codex took over the investigation on 15 October 2026. F1 24 startup and genuine
EAAC driver execution remain unachieved. The deployed runtime and main Wine
checkout remain unchanged. Diagnostic instrumentation exists only in a detached
research checkout and runtime clone. The active EA Desktop session was left running.

The [implementation roadmap](EAAC-IMPLEMENTATION-ROADMAP.md) tracks initialization
repair, genuine driver acquisition, kernel execution, minifilter functionality,
and final gameplay verification in Agora scope `f124-anticheat`.

## Fatal dialog explains the apparent launcher survival

The installed `preloader_l.dll` has SHA-256
`577f2c445b20270a807c5bf92939a3c72a6e55588c63b60d2ab68162cfe138ae`.
Its PE exception table identifies the function containing RVA `0x2310` as
RVA `0x2170` through `0x232f` exclusive.

Focused Ghidra decompilation of that function shows an error-message construction
path followed by `MessageBoxW`. The call returns at RVA `0x2301`. When the
function's termination argument is set, it then calls
`NtTerminateProcess(-1, error)`, with return address RVA `0x2316`.
This matches the return-address offset recorded in the runtime termination log.
Decompiler variable names and recovered types are inferred, not original source.

Evidence:

- `/Users/gc/.agora/work/logs/job-1.log:82–168`: target hash, selected function
  range, and decompilation. Ghidra ran without whole-program analysis. Agora
  reported exit status 0 and elapsed execution time 8.3 seconds.
- `/tmp/eaac_launcher_msgbox.log:40`: `MSGBOX_OnInit` records the fatal
  `E111000D` initialization message. This is a separate launcher capture.
- `/tmp/sample_38898.txt:559–563`: the sampled stack is `NtUserGetMessage` →
  `wait_message` → `NtWaitForMultipleObjects` → `inproc_wait` → `msync_wait_objs`.
  The sample header gives launch time 18:34:13.424 and sample time 18:36:18.700
  local time. It does not identify an awaited driver or network operation.
- The task-6077 runtime log records termination with return address
  `0x6fffe5b22316`, consistent with the installed preloader's RVA `0x2316`.

The UI wait and later termination therefore do not establish successful
initialization or a connection timeout. An externally stopped 25-second capture
does not establish that the launcher avoided the fatal condition.

## Separate launch attempts

The EA Desktop application logs contain multiple launches. The earlier Agora
summary combined their timestamps. In `EADesktopVerbose.log` under the prefix's
`drive_c/ProgramData/EA Desktop/Logs`:

| Observation | UTC timestamp | Log line |
| --- | --- | --- |
| First license reactivation begins | 16:32:10.005 | 26361 |
| Reactivation completes; license remains unreadable | 16:34:11.323–325 | 26371–26372 |
| Launcher created, guest PID 2184 | 16:34:13.486 | 26448 |
| Game process termination, exit `-518979571` | 16:36:34.087–088 | 26811–26812 |
| Another license reactivation begins | 16:36:45.496 | 27054 |
| Launcher created, guest PID 3100 | 16:36:50.622 | 27142 |
| Game process termination, exit `-518979571` | 16:36:53.588 | 27279–27280 |

`-518979571` is the signed 32-bit representation of `0xE111000D`.
Guest PIDs must not be conflated with host macOS PIDs. Log line numbers describe
the files read during this review; live logs can rotate or change.

The first verified license failure is that a reactivation request completes
without a readable `16425782.dlf`. This does not establish why activation failed.
The license file and the configured `eaanticheat.sys` path were both absent when
checked. Neither absence establishes the immediate cause of the preloader verdict.

## Evidence limits and preserved state

The fourth raw syscall returns `STATUS_INVALID_PARAMETER` in the inspected
captures. No Windows reference measurement establishes that this return is wrong.
The displayed target-code bytes are memory dumps, not an execution trace.
No return-value patch is justified by these captures.

Exact syscall-ID matching is required: searching for `wine id 0x5` also matches
`0x50`. The standalone captures contain 308 and 193 exact `0x5` events,
respectively, rather than the previously reported 1,889 and 1,774. These are
syscall observations, not measured UI responsiveness.

Wine was clean on branch `main` at `9accd7e5dc0` when checked. GameHub already
contained a modified `bin/start-ea.sh` and untracked work archives; these were
preserved. `start-ea.sh` issues two game-launch requests after catalog priming,
so process correlation is required before treating repeated attempts as one run.

The REA MCP Ghidra provider was unavailable because its installation path was
not configured. The existing local Ghidra 12.1.4 installation and preserved
`FocusedEAAC.java` script supplied the focused analysis through Agora's work
runner. No MCP configuration was changed and no REA Evidence ID is claimed for
the CLI output.

The unresolved investigation is the failure that selects `E111000D` before the
error dialog opens. Any further capture must distinguish that point from dialog
dismissal, preserve the active EA Desktop session, and keep credentials and
session tokens out of shared artifacts. Genuine driver acquisition and execution
remain separate acceptance requirements.

## Current installer reproduction after CatRoot initialization

The bundled installer is 109,664,312 bytes, SHA-256
`18d5cb9a7ed0fd57ed2f08922a90b47fc1ae65941b9bdf9d27a5ee0ca78b39c0`,
MD5 `f99fef4a4271e7558d7b63df00721d05`. Its adjacent manifest instead specifies
95,422,336 bytes, SHA-256
`fe2ba2b6ebcf523572172ca203c14f4827592146813e0ddb272187115314be5c`,
and MD5 `7e0f4d956cfd79588ba94516d40ff961`. The previous handoff attributed the
manifest hash to the installed file incorrectly. The actual file hash matches
the older archived installer described in `EAAC-HANDOFF-20261015.md`.

The existing isolated prefix at
`/Volumes/ExT2/GameHub/work/eaac-current-install-20261015/prefix` lacked the
CatRoot GUID directory. Codex created that empty directory and reran its genuine
277,175,032-byte current installer with `--install --title f12024` through the
deployed runtime. No catalogs were fabricated and the active EA Desktop prefix
was not changed.

Agora job `job-2` exited 0 after 9.1 seconds. Its log is
`/Users/gc/.agora/work/logs/job-2.log`:

- Lines 55716–55717 show successful `\\SystemRoot` pathname conversion for CatRoot.
- Lines 55728–55732 enumerate `*.cat`, finding zero entries.
- Lines 55753–55778 open and successfully read the existing 48-byte
  `ProgramData/Packer/catcache4.bin`.
- The child's subsequent raw `NtTerminateProcess` receives exit code zero.
- Lines 55835–55890 show the installer replacing the user-mode
  `EAAntiCheatService` registration.

The earlier CatRoot crash did not recur. The expected `eaanticheat.sys` file
remained absent. Installer exit zero and successful service registration do not
establish driver installation or game startup.

Agora job `job-3` then ran `wine sc start EAAntiCheatService` in the same isolated
prefix. It exited 29 after 29.2 seconds total: 20.2 seconds waiting for machine
capacity and 9.0 seconds executing. Its log is
`/Users/gc/.agora/work/logs/job-3.log`:

- Line 5517 records the service opening its genuine GameService DLL.
- Lines 8778–8795 record raw syscall `0x101(-10000)` returning
  `STATUS_INVALID_PARAMETER`.
- Line 8837 records `NtTerminateProcess(-1, 0xE111000D)`.
- Line 8887 reports service startup failure.

The service thread has file tracing enabled, but no logged anti-cheat device
open or IOCTL before termination. Thus the service initialization failure is
reproduced independently of the active EA Desktop session. Successful installer
self-test does not imply successful service initialization.

The protected EA Desktop and background-service processes remained present when
checked. No process was signaled and no deployed runtime was replaced. No build
was run for these diagnostic reproductions.

## Current publisher launcher comparison

The preserved publisher package `RCDATA-102.zip` also contains a newer Title
launcher than the installed game. Its three Title files were extracted into the
isolated prefix's `C:\F1` directory, which previously contained only the genuine
game executable clone and configuration. The active game installation was not
modified.

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| GameServiceLauncher DLL | 52,015,864 | `7d53b70c940e92963ec8d5f30ca0463df0152e1bdfc251114bb4f51374f03b21` |
| GameServiceLauncher EXE | 20,031,736 | `32ed87237e64b96a15135a406ac79063caaf638b975b3467bd9cec6e5d76fcb5` |
| preloader_l DLL | 46,840 | `855b6cddd756fdafe626578b73a9216521fad76319ee2baa113837919ebb3859` |

Agora job `job-6` launched this executable with `--reactivate` in the isolated
prefix. Its private capture is
`/Users/gc/eaac-archive/eaac-acquisition-20261015/codex-current-launcher-isolated.log`.
Line 3704 records the stub-patch gate for the launcher; lines 6905–6922 record
syscall `0x101(-10000)` returning `STATUS_INVALID_PARAMETER`; line 8190 records
`MSGBOX_OnInit` with `E111000D` at diagnostic location `00457425`.

The wrapper terminated only its launched host process, PID 98791, when the
12-second observation deadline expired. Its result was `-15`, externally
bounded, at 12.055 seconds. Agora's wrapper job exited zero after 12.8 seconds;
that is not a successful launcher result. The active EA Desktop processes
remained present. No account/session credentials were supplied to this isolated
activation attempt, so it does not test account activation end to end.

Job `job-5` was an empty Python invocation: Agora did not pass the caller's
heredoc stdin to the job. It launched no target and supplies no test evidence.
Job `job-6` corrected that invocation by passing the code as a command argument.

Updating only the title launcher therefore does not eliminate the initialization
error in this isolated environment. No active game file replacement is justified
by this comparison.

Focused decompilation of the older installed preloader's initialization functions
also completed in job `job-4` (exit zero, 8.8 seconds). Its log shows the error
reporter installed as a callback in the context passed to the manually mapped
launcher DLL. Thus an error reported through that callback is not by itself a
failed Wine API result. The exact condition selecting `E111000D` remains unknown.

## Bounded syscall-context capture and offline continuation replay

The debugger startup/early-attach route failed in Rosetta DebugServer, including
the assertion `gTaskSuspended` in `DebugServer.cpp:344`. A no-breakpoint control
also terminated with SIGTRAP. These attempts produced no usable pre-syscall
context and are not successful captures.

Codex created the detached research checkout
`/Volumes/ExT2/GameHub/work/codex-eaac-context/src` at `9accd7e5dc0` and added
temporary diagnostic logging to its macOS SIGSYS handler. The trace uses the
existing permission-checked memory reader, records at most four relevant probes
per process, and copies at most 2 KiB per probe. It does not alter syscall results.
All Unix ntdll objects were built from that checkout; stale build objects were
not reused. Only a research runtime clone received the diagnostic ntdll.

Agora jobs `job-48`, `job-63`, and `job-68` are the three successful diagnostic builds
(7.1, 1.6, and 1.9 seconds of execution). There were no release builds or product test
suite runs. The first build reported pre-existing unused-global warnings in
`dlls/ntdll/unix/server.c:106` and `system.c:263`; these were not repaired.
The two incremental builds reported no warnings. Configuration required the
existing LLVM-MinGW and Homebrew Bison paths; earlier configuration failures
were setup failures, not source compilation failures.

Job `job-64` captured all four probes and reproduced the fatal dialog. Its
launcher was stopped after the bounded observation period, so launcher status
`-15` is not a successful initialization result. The diagnostic acceptance
checks passed because four complete context records and the fatal dialog were
present. Evidence file:
`/Users/gc/eaac-archive/eaac-acquisition-20261015/codex-four-probe-context-run.log`.

| Probe | Raw syscall | Continuation RIP | First argument |
| --- | --- | --- | --- |
| 0 | `0x4` | `0x10058fa13` | `-1` |
| 1 | `0x4` | `0x1005e6e48` | `-10000` |
| 2 | `0x4` | `0x1005ec72a` | `-1` |
| 3 | `0x101` | `0x1004db985` | `-10000` |

The fourth captured context has RSP `0x31e690`, RFLAGS `0x246`, RDX/R8/R9 zero,
and R10 `0xffffffffffffd8f0`. The handler supplies `STATUS_INVALID_PARAMETER`
and the documented syscall continuation registers. The dialog reports
`E111000D` at `00457425`.

The bounded offline replay script is preserved as
`codex_replay_captured_context.py` in the same private evidence directory. It
uses the previously captured mapped image and the new register/stack records.
It tracks initialized stack bytes and stops before reading uncaptured stack or
unmapped external memory; its instruction budget is 20,000. Unicorn 2.1.4 and
Capstone 5.0.9 exist only in the research analysis virtual environment.

With the existing fourth-syscall result, replay reaches the error callback at
`0x100557422` after 2,911 instructions, with RCX `0xe111000d` and RDX `1`.
It stops at the callback-table read at `0x6ffffd5fa0b0`, which was not captured.
This is offline instruction evidence, not an end-to-end execution or a Windows
reference measurement. Jobs `job-59` and `job-61` include stack-read validation.

Job `job-65` replays the three preceding continuations using the statuses
already established by focused Wine probes (`0x102`, `0xc0000008`,
`0xc0000005`). They reach exactly the next observed syscall locations after
3,061, 2,230, and 1,818 instructions respectively. These supplied statuses are
assumptions from the Wine reproductions, not newly captured Windows returns.
Job `job-66` additionally checks every general-purpose register and the next RIP
against the subsequent live capture: all sixteen registers and RIP match for
each of those three continuations. The mapped image came from a separate run;
these comparisons validate the observed paths, not every mutable image byte.

Offline comparisons in `job-60` show that all seven sampled fourth-return
values still reach the same fatal callback. `STATUS_INVALID_HANDLE` takes an
additional branch and reaches it after 4,860 instructions (`job-62`). This
refutes the proposed idea that substituting any one of those fourth-return
values alone resolves initialization. No such substitution was applied to a
running launcher. Subsequent predicate tracing below identifies the actual
return comparison. Its Windows contract and an initialization repair remain
unresolved; no runtime fix is claimed.

## Driver acquisition continuation

The user deferred a Windows x64 reference capture until later. Local artifact
inspection continues under task-8; the absence of that capture does not turn an
inferred Windows behavior into a fact.

The current service DLL has two opaque RCDATA payloads, IDs 10100 and 10150,
at file offsets 5553088 and 6210528, of lengths 657440 and 6158336. Each begins
with a little-endian length (657435 and 6158329), followed by a common four-byte
prefix `e0104f78`, and respectively one or three trailing zero bytes. Two other
locations in the same DLL share that prefix. These structural observations do
not establish compression, encryption, or a driver identity.

Bounded Brotli decoding failed both with the original lengths (`job-72`) and
with exact length-prefixed input plus a 32 MiB output budget (`job-76`). No
decoded output was accepted. `job-73` scans current and bundled installers and
all six current package binaries for bounded, structurally valid embedded PE
headers. It finds only the outer GUI PE in each file, with no nested native
driver candidate. The inventory is preserved as `codex-embedded-pe-inventory.json`.
This does not exclude transformed or compressed drivers.

Job `job-70` captured 63,258,624 bytes from address `0x100000000` in an isolated
service process after its fatal modal dialog. SHA-256:
`cf2b2f019f9858d1cf121c3ecb112ee203100fd9ab467c7534dc35e89b0107cb`.
The filename `codex-service-full-image.bin` is historical: subsequent inspection
finds the actual PE header at capture offset `0x100000`, declaring ImageBase
`0x100100000` and SizeOfImage `0x3c54000`. The capture therefore includes a prefix
and omits the module's final MiB; it must not be treated as a complete module.
Resource byte ranges inspected here are fully inside the captured region.
The optional pre-termination stop diagnostic in `job-69` did not trigger before
its timeout because this standalone service was waiting at a fatal modal dialog.
The owned research processes were terminated; EA Desktop was not signaled.

The bundled installer's resource 102 was independently inventoried by REA:
`ev_ffdec44e0a8f68dd28600b41d33a83d40f166a34b6bf9f58383fc9497d4b60b3`.
Job `job-74` extracts its original service DLL, 26,830,656 bytes, SHA-256
`94e2533f34da836c6227a0d4296123d7dd1bbee2fce7f5d987d87d00ed3353c7`.
REA inventory `ev_94f2f4dfe8661f2c47fbdf23a7e2805bcfd915ee948fa60687d6d2ad79ef9f92`
shows that older DLL lacks the two current opaque RCDATA resources. It has only
RCDATA 10001 alongside dialog and manifest resources.

`job-78` finds one reference near another shared-prefix blob; focused Ghidra
analysis in `job-79` identifies it as a reference to the adjacent `true` text
used by a formatting routine. It supplies no decoder identification. No genuine
driver has been recovered or authenticated, so task-8 remains incomplete.

## Corrected module base and observed return comparison

The old launcher-region analysis incorrectly treated `0x100000000` as the DLL
base. Its PE header actually begins one MiB later and declares ImageBase
`0x100100000`. Job `job-81` recaptured the complete 52,101,120-byte module from
that base, validated its DOS/PE headers, ImageBase, and SizeOfImage, and produced
`codex-launcher-complete-module.bin`, SHA-256
`3d04844246600418855e122a0d002a0de6aabe9cda93c139675093172a3bfa14`.
The previous claim that the displayed error offset pointed into read-only data
was incorrect: callback return `0x100557425` minus the actual DLL base equals
the displayed RVA `0x457425` exactly.

The genuine PE exception table identifies the syscall fragment at RVA
`0x3db956..0x3db9aa`, continuation routine at `0x13bcc4e..0x13be793`, and error
caller at `0x45731a..0x45831a`. Correctly based focused Ghidra analysis in
`job-83` still cannot recover the obfuscated indirect jump table; no complete
decompilation is claimed. The derived analysis PE is never executed.

The replay now uses the complete correctly based module. Job `job-82`
revalidates all three preceding continuations against the live register
captures and reproduces the fourth error path with the same instruction counts.
Job `job-86` records the concrete comparison operands: at `0x1014bcfbd`,
`cmp ebp, esi` compares actual result `0xc000000d` with `0xc0000008`.
Repeated comparisons in the same obfuscated routine use the same operands.
The latter is STATUS_INVALID_HANDLE, not STATUS_INVALID_PARAMETER. This
captures a relevant CPU-state discrepancy on the path selecting the fatal
callback; it does not prove which Windows operation should have been invoked.
Task-7's capture deliverable is complete on this evidence. Initialization
repair and final gameplay remain incomplete.

The syscall number is version-dependent. The original primary dataset used by
Wine's generated table assigns `0x101` to NtInitializeRegistry on Windows 10
22H2 and NtGetNextThread on Windows 11 24H2/25H2:
https://github.com/j00ru/windows-syscalls/blob/master/x64/csv/nt.csv.
This suggests a syscall-profile selection hypothesis, not an established cause.
Job `job-87` measures the isolated prefix's `cmd /c ver` as 10.0.19045.
Job `job-88` independently captures KUSER_SHARED_DATA NtBuildNumber `0x4a65`
(19045), NtMajorVersion 10, and NtMinorVersion 0 in the service process.
The measured shared fields do not demonstrate a version mismatch.

Job `job-88` also supplies the complete correctly based service module,
63,258,624 bytes, `codex-service-complete-module.bin`, SHA-256
`ed84fa5a5b24c6bdcf5f0d34c93eedbf9fcd38fdd2fe689c45356984cad940eb`.
This replaces the partial service region for future full-module analysis.
The reproducible capture script is `codex_capture_module.py` in the private
evidence directory. No production runtime or main-checkout changes were made.
