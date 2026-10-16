# Installer path recovered — 2026-10-16

Artifact: EAAntiCheat.Installer.exe, 277175032 bytes, SHA-256
`d0396b7fe0331cef94278ed015c93012cd9ab67eb02e3775abd6660e96f5b6eb`.
All addresses below belong to this artifact at preferred base 0x140000000.
This is static analysis, not proof that a prior run executed every stage.

## Established chain

1. CLI parser 0x140026a94 decodes operation keys through 0x14002ec80.
   Keys include install, title, read-cfg, update and update-title. The trim helper
   0x14002dbad uses first-not-of/last-not-of searches for UTF16 '-'; therefore
   --install and --title normalize to recognized keys. A command syntax error
   from an extra leading hyphen is not supported by this code.
2. The install branch calls coordinator 0x1400200e0. Constructor 0x14001ff74
   assigns the registry object to offset0x20 and payload/path object to offset0x10.
   The constructor has no matching pdata entry; its selected analysis upper bound
   was the next known function, not a proven exception-table boundary.
3. First gate: offset0x20 object, vtable0x14009f310 slot0x18 -> 0x14003dac0.
   It writes title registration and checks kernel-service configuration. A false
   result stops the coordinator before the next installation stage.
4. Missing kernel key invokes fallback0x14003e47c. Its inspected write helpers
   0x1400468c4/0x140046998 call RegSetKeyValueA/RegSetValueExA. This path configures
   registration; no driver-file acquisition operation was identified in it.
5. Next gate: offset0x10 object, vtable0x14009e970 slot0x20 -> 0x140013320.
   The method creates/checks paths through helpers, copies the installer with
   CopyFileExW, calls helper0x14001075a with resource ID102, checks a child path,
   and creates a child with an appended PACKER_FUNCTIONALITY token.
6. The child suffix is 25 UTF16 code units at RVA0x9ea58. It includes non-ASCII
   control values; preserve the exact bytes instead of replacing it with a guessed
   --selftest flag. Private artifact packer-child-argument-20261016.json records it.
7. The method waits up to10000ms. On its inspected paths it calls TerminateProcess
   and closes handles after logging the wait result. It does not call
   GetExitCodeProcess here. The subsequent virtual call is now resolved below; no claim is made that
   every possible installer operation ignores child outcome.

## Concrete driver registration

Decoded configuration includes kernel-service key
SYSTEM\CurrentControlSet\Services\EAAntiCheat, expected driver suffix
\drivers\eaanticheat.sys, DependOnService FltMgr, Group FSFilter Activity Monitor,
Type2, Start3, instance altitude363250, DefaultInstance and Flags0. Type2 and
Start3 are immediate arguments to the inspected DWORD writer; their OS meanings
are not inferred here. These are publisher registration requirements, not a
recovered driver import/behavior matrix.

The isolated system.reg snapshot contains the EAAntiCheat kernel-service and
instance keys under System\ControlSet001. Its CurrentControlSet entry is explicitly
a symbolic link to that control set. The expected ImagePath is
system32\drivers\eaanticheat.sys, but that file is absent. The initial exact-path
missing-key result was invalid and is superseded by the alias-resolved snapshot
(kernel-service-registration-snapshot-20261016.json). SOFTWARE\EA also exists
through descendants even though its empty parent is not explicitly serialized.
No registry entries were fabricated or repaired. Snapshot presence does not prove
that a particular installer run executed or passed the corresponding gate.

## Evidence and guardrails

Private evidence root: /Users/gc/eaac-archive/eaac-acquisition-20261015.
Focused outputs: installer-handler-focused-20261016.log,
installer-coordinator-focused-20261016.log, install-prerequisite-focused-20261016.log,
kernel-registration-fallback-focused-20261016.log,
kernel-registry-writers-focused-20261016.log, option-normalization-focused-20261016.log,
option-trim-search-focused-20261016.log, payload-object-focused-20261016.log and
post-registration-install-focused-20261016.log. Jobs100–117 are copied to durable
static-acquisition-job-N.log files. One decoder query failed because a key-table
slice end was not updated; the corrected query and limitation are recorded in E-009.

Ghidra project ghidra-installer-control/installer is retained. Whole-program
analysis stayed disabled. The retained decoder research/eaac/decode_installer_strings.py
pins the artifact hash and checks scalar/vector-prefix masks before accepting strings.

Zero target launches and zero builds in this block. Driver acquisition remains
incomplete. These findings replace guesses about CLI syntax and install sequencing;
they do not establish a Wine root cause or successful anti-cheat execution.
The resource102 helper, child identity and final virtual call were subsequently
resolved below. Do not repeat standalone service launches, mutate registration,
or guess resource compression.


## Resource102 and child follow-up — E-013/E-014

Helper0x14001075a retrieves RCDATA102 through FindResourceW, LoadResource,
SizeofResource and LockResource, opens the returned buffer as an archive and
iterates entries. This is the existing publisher archive extraction path, not
an identified consumer of service resources10100/10150. Downstream extraction
helpers were not exhaustively analyzed; no recovered-driver claim is justified.

Historical runtime evidence already names the child:
C:\Program Files\EA\AC\eaanticheat.gameservice.dll itself, launched as a process.
current-installer-private-install.log:947,950 and job-2.log:55200,55298 record its
command line and NtCreateUserProcess. The non-ASCII PACKER_FUNCTIONALITY token
matches the saved static suffix. This is not EAAntiCheat.GameService.exe with no
arguments. Helper0x140002665 handles string concatenation/length, not an environment
block in the inspected caller; CreateProcessW receives a null environment pointer.

Job-2's child reaches CatRoot and reads48bytes from catcache4.bin after the earlier
CatRoot correction. This historical observation is already established and must
not be repeated merely to obtain another installer exit0. The older install trace
also contains a pre-correction child crash; do not merge those attempts.
Exact excerpts and source hashes are retained in
installer-child-identity-evidence-20261016.json.

The final virtual call at0x1400138e3 uses slot0x28 of vtable0x14009e970, resolving
to0x140013f20. If field0x238 is nonzero, this short method invokes the same
resource102 extractor using another encoded section name and destination at0x228;
otherwise it returns1. It does not query the child exit code or directly write a
driver. The section name remains unverified; do not label it from string length.

New evidence: resource102-child-focused-20261016.log,
final-install-method-focused-20261016.log and static-acquisition-job-118..120.log.
Job118 executed6.3s; job1190.6s; job1205.6s, according to Agora. These are analysis
execution times, not total effort or a speedup measurement. Zero new target launches
and zero builds in this follow-up. Ledger records E-013/E-014 are closed.

Decision: no repeated installer or standalone-service launch is warranted by these
results. The actual writer/acquisition operation for the expected driver file is
still unidentified. Resource102 extraction, child certificate-cache work, and
registry configuration are separate observed stages; none proves driver recovery.
Task-8 stays incomplete and the syscall deployment gate stays failed.
