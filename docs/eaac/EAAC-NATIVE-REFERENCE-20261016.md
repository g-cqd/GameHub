# Native Windows reference without a Windows machine

Microsoft-hosted kernel10.0.19041.5794, SHA-256
f394a43b4aad1936af9a4fc6954904c22b9193a105b26cb9113a18652068eed4,
passes LIEF1.0.0 default Authenticode and content-hash verification.
Winbindex supplied index metadata only; the binary came from Microsoft:
https://msdl.microsoft.com/download/symbols/ntoskrnl.exe/5B5EC8781046000/ntoskrnl.exe

PDB GUID7A49711F-9BF9-37DF-3C52-C7A5B94C4DD7 matches PE CodeView.
DBI age1 matches PE age1; PDB information-stream age5 is separately recorded.
Matching Microsoft URL and artifact hashes are in native-kernel-reference-manifest.json.
No Windows machine, VM, kernel execution or runtime reference capture was used.

The on-disk service-table entries are RVAs, not runtime signed-shift offsets.
Entry0x101 is78df90 (NtInitializeRegistry); entry0xf9 is6ba070 (NtGetNextThread).
Native NtInitializeRegistry compares low16flags. Its user path delegates non13e8
calls through ZwInitializeRegistry; the kernel path rejects flags outside0..2 and
1000..13e7 with C000000D. This supports the original capturedD8F0 result.
Microsoft documents the Zw wrapper's PreviousMode transition:
https://learn.microsoft.com/en-us/windows-hardware/drivers/kernel/previousmode

User flag13e8 takes a separate privilege check and can returnC0000061. Therefore
neither an unconditional NtGetNextThread alias nor a blanket13e8 ACCESS_DENIED
fixture is justified. The latter is tracked separately in Agora.

Removed the nine-line alias from main/research winsyscall.c. Both resulting
source files SHA-256 ed4ae31e9cc81e984a1231efe6e5d84cae3da8c8d940d991482abafd02c294c7.
Identical six-case mapped executable: baseline6failures/exit1; corrected0failures/exit0.
One diagnostic compile and one focused ntdll build passed. Research replacement
was signed, verified and atomic; its original runtime backup is retained.
Full Wine suite was not built/run. Production runtime was not modified.

Actual production F1 launch still fails E111000D at0026FA30. Its installed
preloader and both launcher binaries pass signature/hash verification. They
are different from the newer research launcher that failed at00457425.
The production fatal was documented historically; this session revalidates it.
The signed preloader includes Wine rejection and emulation-disabled strings,
but no supported Wine capability contract was established by the selected
init/helper analysis. A string is not evidence that the corresponding path runs.

Private evidence root: /Users/gc/eaac-archive/eaac-acquisition-20261015.
Jobs133..166 are copied there. E018..E024 preserve hypotheses, limits and results.
F1 protected gameplay and the causal fatal predicate remain unverified.
