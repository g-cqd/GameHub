# T5a: PE scanner, folder markers, executable finder (spec; implement exactly, report, do not improvise)

Untrusted-input parser: it must never trap, never read out of bounds, and bound every loop. Swift 6, `package` access, value types, typed throws
`throws(HubError)` (`HubError.invalid("PE: <reason>")`). No force unwraps, no `try!`, no unsafe pointers (index into `[UInt8]`/`Data` with explicit bounds checks),
all offset arithmetic via `Int` after range-checking each operand, or `addingReportingOverflow`.
Files: `Sources/HubCore/Scan/{PEScanner.swift, FolderMarkers.swift, ExecutableFinder.swift}`, tests `Tests/HubCoreTests/PEScannerTests.swift` with a
synthetic fixture builder `Tests/HubCoreTests/PEFixture.swift` (generates headers; never uses real game bytes).

## PEFacts
`package struct PEFacts: Codable, Equatable, Sendable { machine: String; pe32Plus: Bool; isDLL: Bool; subsystem: String; sections: [String]; imports: [String];
delayImports: [String]; timestamp: UInt32 }`. machine: 0x14c -> "i386", 0x8664 -> "x86_64", 0xaa64 -> "arm64", other -> String(format "0x%04x").
subsystem: 2 -> "gui", 3 -> "console", other -> "other:<n>". imports/delayImports: DLL names lowercased, deduplicated, sorted.
## PEScanner
`package static func parse(_ bytes: [UInt8]) throws(HubError) -> PEFacts`; `package static func read(_ url: URL, limit: Int = 512 << 20) throws(HubError) -> PEFacts`
(regular file via lstat, size <= limit, `Data(contentsOf:options: .alwaysMapped)` then `[UInt8]`).
Layout rules (all little-endian): `MZ` at 0; e_lfanew = u32 at 0x3C, must satisfy 0x40 <= e_lfanew <= min(size - 24, 0x1000_0000); `PE\0\0` at e_lfanew;
COFF at e_lfanew+4: machine u16 @0, numberOfSections u16 @2 (1...96), timeDateStamp u32 @4, sizeOfOptionalHeader u16 @16, characteristics u16 @18
(isDLL = bit 0x2000). Optional header at opt = e_lfanew+24, must fit in sizeOfOptionalHeader and the file: magic u16 0x10b (PE32) or 0x20b (PE32+), else reject.
ImageBase: PE32 u32 @opt+28, PE32+ u64 @opt+24. Subsystem u16 @opt+68. NumberOfRvaAndSizes u32 @opt+92 (PE32) / @opt+108 (PE32+), capped at 16;
data directories begin @opt+96 / @opt+112, 8 bytes each (rva u32, size u32); entry 1 = imports, entry 13 = delay imports (absent if index >= count).
Section headers start at opt + sizeOfOptionalHeader, 40 bytes each, must fit in the file: name 8 bytes (stop at NUL; bytes outside 0x20...0x7e become `?`),
VirtualSize u32 @8, VirtualAddress u32 @12, SizeOfRawData u32 @16, PointerToRawData u32 @20.
rvaToOffset(rva): the first section with VA <= rva < VA + max(VirtualSize, SizeOfRawData) and (rva - VA) < SizeOfRawData; offset = PointerToRawData + (rva - VA);
must be < file size; else nil.
Imports (if rva != 0): descriptors of 20 bytes from rvaToOffset(rva); stop at an all-zero descriptor; at most 1024 descriptors (more -> reject); Name RVA u32 @12.
Delay imports (if rva != 0): descriptors of 32 bytes; stop at all-zero; at most 1024; Attributes u32 @0, DllNameRVA u32 @4; if Attributes bit 0 is 0 the value is
a VA: subtract ImageBase (if value < ImageBase -> skip that entry). Names: ASCII string at rvaToOffset(name), stop at NUL, max 256 bytes (no NUL within 256 ->
reject), only bytes 0x21...0x7e allowed (else reject). Unmappable name RVA -> reject the file. Never throw on unknown machines or subsystems.
## FolderMarkers
`package enum FolderMarkers { package static let known: [(marker: String, hint: String)]; package static func scan(root: URL) -> Set<String> }`.
Known markers (exact strings, hint in parentheses): `__Installer/installerdata.xml` (ea), `steam_api.dll` (steam), `steam_api64.dll` (steam),
`steam_appid.txt` (steam), `EOSSDK-Win64-Shipping.dll` (epic), `EOSSDK-Win32-Shipping.dll` (epic), `.egstore` (epic), `uplay_r1_loader.dll` (ubisoft),
`uplay_r1_loader64.dll` (ubisoft), `upc_r2_loader64.dll` (ubisoft), `uplay_r2_loader64.dll` (ubisoft), `PnkBstrA.exe` (punkbuster), `EasyAntiCheat` (anticheat),
`BattlEye` (anticheat). A marker is found if it exists (case-insensitive name match per component, via directory listing, NOT following symlinks:
use `lstat`, a symlink never matches) directly under `root` or under any immediate subdirectory of `root` (at most 256 subdirectories examined). Returns the
canonical marker strings as listed (not the on-disk case).
## ExecutableFinder
`package static func candidates(root: URL, limit: Int = 64) -> [URL]`: regular files with extension `.exe` (case-insensitive) up to depth 3 below root,
never following symlinks (FileManager enumerator with `.skipsPackageDescendants` and checking `isSymbolicLink`; skip symlinked dirs), excluding names
(case-insensitive) matching prefix `unins`, containing `setup`, `vcredist`, `dxsetup`, `crashreport`, `easyanticheat`, `battleye`, `activation`, `touchup`;
sorted by file size descending then path; at most `limit`.
## Tests (>= 14)
Fixture builder: `PEFixture.make(machine: UInt16, pe32Plus: Bool, subsystem: UInt16, dll: Bool, imports: [String], delayImports: [String], delayUsesVA: Bool) -> [UInt8]`
laying out headers, one `.rdata` section holding descriptors and names, one `.text` section.
Cases: i386 GUI imports d3d9+dsound; x86_64 console imports dxgi+d3d11 with delay steam_api64.dll (RVA style) and one with VA style; DLL flag; unknown machine
string; truncation at every 7th length from 0 to full size never traps (throws or parses); e_lfanew = 0xFFFFFFFF rejected; numberOfSections 0 and 0xFFFF
rejected; name without NUL in 256 bytes rejected; name RVA 0xFFFFFFFF rejected; 2000 non-zero descriptors rejected; non-ASCII import name rejected;
markers: temp folder with `Bin32/steam_api.dll`, `__INSTALLER/InstallerData.xml`, a symlink named `.egstore` (must NOT match); finder excludes
`unins000.exe`/`Setup.exe`, does not descend into a symlinked dir, orders by size.
## Done
`swift build --scratch-path <scratch>` and `swift test --scratch-path <scratch> --filter HubCoreTests` succeed (prior 99 tests still pass). Report files, counts, deviations.
