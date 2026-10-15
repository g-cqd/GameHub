# EAAC acquisition without a Windows host — 15 October 2026

> Takeover state: see [EAAC-HANDOFF-20261015.md](EAAC-HANDOFF-20261015.md). Later current-installer traces and independent SystemRoot probes supersede the early-session status statements below.

The user confirmed that no Windows machine is available. Acquisition must use the
existing EA artifacts or a verified publisher download. No driver has been obtained,
and no compatibility implementation or performance result is claimed.

## Scope and order

1. Identify the archived installer payloads and their resource containers.
2. Recover the actual driver or establish its acquisition flow from evidence.
3. Inspect the recovered driver's imports and execution requirements before selecting
   compatibility changes and writing their regression tests.
4. Verify genuine driver execution and game startup before measuring performance.

The current `REVERSE-ENGINEERING.md` explicitly authorizes anti-cheat interoperability
analysis. Older checkpoint statements that this analysis is out of scope do not
describe the current request. The requirement remains to execute the genuine driver.

## Observations

The archived `RCDATA-102/ProgramFiles/EAAntiCheat.GameService.dll` has SHA-256
`b0de4818d365f6f02a970a7eb77cb57a4b4a141e94ba177056d321da0f746e2d`.
REA's portable PE parser reports machine 34404 (`0x8664`, x86-64), seven resources,
and complete resource-directory coverage. Its opaque payload coverage does not
identify executable content inside those resources.

Resource Evidence: `ev_9b7feb907c88b386762095bdecc03d06a21302fdc078621dabd016350fd223cc`.

| RCDATA ID | File offset | Bytes | Result |
| --- | ---: | ---: | --- |
| 10001 | 12368864 | 393178 | Zstandard frame, decoded successfully |
| 10100 | 5553088 | 657440 | Unidentified opaque payload |
| 10150 | 6210528 | 6158336 | Unidentified opaque payload |

Resource 10001 decodes to 579922 bytes with SHA-256
`8e4d01daf27ed4949de41a64606fb775c324c1aef3945c8306b3363048ce9820`.
A sequential, little-endian 32-bit length-prefixed parse consumes the entire output
as 488 records. Every record parses successfully with `openssl x509 -inform DER`.
This establishes certificate content; it does not establish the certificates' use.
The output contains no `MZ` candidate with a valid referenced PE signature.

Neither opaque resource contains an immediately recognizable embedded PE header.
Brotli decoding of each complete opaque resource fails with `corrupt input`.
These bounded negative checks do not exclude encrypted, compressed, or transformed
driver content. The older report's categorical claim that no driver is bundled is
therefore not established by this inspection.

Apple and Homebrew LLVM objdump both label the artifact `coff-arm64ec`, despite
the x86-64 PE machine field. Disassembly switches instruction families within the
image. Architecture and hybrid metadata require reconciliation before relying on
those tools' decoded instructions.

## Initial Hopper blocker (worked around below)

The older checkpoint's general statement that Wine cannot host Windows drivers is
too broad. Current local source routes kernel and filesystem driver services to
`winedevice` (`wine/programs/services/services.c:950` relative to Developer),
and its NT kernel compatibility module loads driver images with `LoadLibraryExW`
(`wine/dlls/ntoskrnl.exe/ntoskrnl.c:4011`). Direct `NtLoadDriver` is still a
`STATUS_NOT_IMPLEMENTED` stub (`wine/dlls/ntdll/unix/system.c:4646`). These are
source observations, not evidence that EAAC executes correctly. The actual driver
is needed to determine which loading path and missing semantics matter.

REA selected Hopper with the WinPE loader and `--intel-64`. The first
`binary_overview` failed with `cleanup_incomplete`: its underlying startup waited
120000 ms for bridge readiness and timed out. No bridge socket appeared in the
reported private runtime directory. The launcher returned status 0, which does not
establish that the bridge connected.

During the first pass, read-only UI inspection found a Hopper window named
`EAAntiCheat.GameService.hop`, with no additional window reported. Its unsaved state
is unknown. Do not close that document until its preservation requirements are
known. That pass obtained no successful native decompilation or download-flow trace.

## Preserved evidence and changes

`/Users/gc/eaac-archive/eaac-acquisition-20261015/` contains the decoded certificate
resource, the exported REA resource evidence, and a SHA-256 manifest. The directory
is mode 0700 and the decoded artifact and manifest are mode 0600. No EA binaries,
game files, Wine code, registry entries, or deployed runtimes were changed.
No builds or tests were run because this pass changed no implementation.

The driver acquisition, compatibility layer, genuine driver execution, and F1 24
performance target remain unresolved.

## Continued analysis: Hopper alternatives

The user confirmed Ghidra and radare2 are installed. Ghidra 12.1.4 is at
`/opt/homebrew/Cellar/ghidra/12.1.4/libexec` and includes
`Ghidra/Features/Decompiler/os/mac_arm_64/decompile`. radare2 and rabin2 are at
`/opt/homebrew/bin/`, version 6.2.4. These tools replace the blocked Hopper path
for this investigation. No Codex MCP configuration was changed.

For REA CLI calls, set `GHIDRA_INSTALL_DIR` to that installation and select
`--provider ghidra`. The active MCP server still has its earlier environment;
CLI success does not establish that the MCP server can select Ghidra.
radare2 observations below come from direct shell commands, not REA Evidence.

A separate official Ghidra archive was downloaded and its SHA-256 matched the
published release digest. The duplicate archive and extracted directory were
removed after locating the user's Homebrew installation.

### Preloader results

REA/Ghidra completed the following `work` jobs with status 0:

| Job | Query | Elapsed time |
| --- | --- | ---: |
| 1510 | PE entry at `0x18000b030` | 21.6 s |
| 1512 | Preloader overview | 15.9 s |
| 1514 | Function at `0x1800037e0` | 15.1 s |
| 1516 | Initialization at `0x180002390` | 15.8 s |

These are analysis durations, not game performance measurements. The overview
reports 103 procedures and 104 defined strings. Evidence:
`ev_e24a2dce874bf9fd76d75e7575d6f61b3b66a1a68f4f44b1b0a156aeb2f175e5`.

The PE entry contains `UD2`; Ghidra's invalid-instruction pseudocode is not
evidence of a decompiler startup failure. The `.entry` data also contains the
RVA `0x37e0`. At `0x1800037e0`, Ghidra observes initialization followed by an
indirect transfer through a global pointer, with a high bit added to the reason
argument. Evidence:
`ev_c81c8636bf5375dbd0452d402ef175e3956f842b7f2317eebcda089d5679994c`.

Initialization at `0x180002390` resolves `wine_get_version` and
`RtlWow64GetProcessMachines`, reads version resources, opens
`EAAntiCheat.GameService.dll`, and has section-map and manual-map paths. It derives
the eventual transfer target from the mapped image's entry RVA. Ghidra reports
unresolved indirect transfers and incomplete type recovery; this is static
pseudocode, not an observed execution. Evidence:
`ev_1f03afdb5ed60a4a403bd1ac6c2d6246194a31d1e8b3dab4bedaf8431ed3738b`.
No checks were patched, and this result does not demonstrate driver acquisition.

### GameService observations

radare2 identifies the DLL as AMD64 and decodes the entry jump at
`0x20044b590` to `0x200cb7cba`. At that destination it decodes a register-saving
x86-64 prologue followed by indirect control flow. This supplies a usable
instruction decoder despite LLVM's architecture switching. It does not establish
that every mapped code region is x86-64 or explain LLVM's classification.

A byte search for little-endian resource IDs found plausible instructions using
10001 at `0x2004f66ad` and `0x2004f6760`, followed by indirect calls. IDs 10100 and
10150 occurred only in the resource-directory records in this search. This does
not rule out calculated, encoded, or indirectly selected IDs. The corresponding
radare2 output is preserved as `gameservice-cert-resource-consumer-radare.txt`.

The EXE has only version and manifest resources in its complete resource-directory
inventory. Evidence:
`ev_000ffba036db30a78978f00ff075c90a81d18ae1050f7d10df0eb0f0a3c61ff5`.
The deployed GameService DLL is byte-identical to the archived DLL. Evidence:
`ev_654db32e029e12d7f781eefab9f4184874de6924603288dc73b02f8de7bffa07`.

The expanded resource evidence, preloader JSON results, and radare2 disassembly
are preserved in the acquisition archive. The original Hopper blocker has been
worked around; the two opaque resources and driver acquisition remain unresolved.

The full GameService query (job 1515) failed with `provider_timeout` after
5 min 32 s. Its diagnostics show a successful PE import using
`x86:LE:64:default:clangwindows`, followed by whole-image analysis that did not
finish within REA's 330000 ms startup limit. No GameService decompilation was
returned. The complete failure record is preserved as
`gameservice-ghidra-startup-failure.log`. Repeating the same full-image query is
not justified; subsequent work must narrow the analysis or change the analysis
strategy. Native preloader decompilation and radare2 instruction inspection remain
usable without Hopper.
