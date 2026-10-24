# T5a remaining TO DO (from the Sonnet verifier; every item is required; report, do not improvise). Worktree /Volumes/ExT2/GameHub/work/wt-hub-c.
1 B1 tests: PEFixture.make with Array(repeating: "a.dll", count: n): import table 1024 parses, 1025 throws (message contains "too many"); delay table (delayImports:) same pair.
2 B2 test: makeTempRoot dir with tool00.exe..tool63.exe (10 bytes each) + game.exe (10_000 bytes): candidates(root:)[0].lastPathComponent == "game.exe" and count == 64.
3 S4: parse works on [UInt8] directly: le16(_ b: [UInt8], _ o: Int)/le32 free/private helpers replace the Data extensions; no Data(bytes), no subdata (use Array(b[x..<y]) or index loops);
  read = size check (lstat regular file <= limit) then Data(contentsOf: url) WITHOUT .alwaysMapped, then Array once.
4 S5 FolderMarkers: list root once and reuse; buildIndex indexes by lowercase name WITHOUT stat per entry; lstat only entries that match a marker component; one totalEntries
  bound (stop scanning when > 4096 * 257 entries examined overall, and <= 4096 per directory); two-component markers use the subdirectory's index.
5 S6/S7 ExecutableFinder: `guard (try? item.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == false else { continue }`; name filter (.exe + exclusions) before any
  stat for files; one resourceValues call with [.isSymbolicLinkKey, .isDirectoryKey, .isRegularFileKey, .fileSizeKey].
6 S9 + reasons: test with an empty import DLL name (NUL at the name offset) expects "empty DLL name"; every reject test catches HubError.invalid(m) and checks m contains the
  intended reason fragment (e.g. "e_lfanew", "numberOfSections", "terminat", "unmappable"/"RVA", "non-ASCII"/"ASCII", "too many") — use the actual message texts in PEScanner.swift.
7 Truncation: for every length 0..<fullPE.count call parse WITHOUT swallowing in a way that hides traps (a throw is fine, record nothing); assert try PEScanner.parse(fullPE)
  succeeds; sectionTableEnd = PEFixture.peOffset + 24 + optionalSize + 2*40 and every length < sectionTableEnd throws.
8 skipsSymlinksFixture asserts found == ["steam_appid.txt"]; rejectsZeroSections/rejectsExcessiveSections use PEFixture.coffOffset + 2 (no local coffOffset/e_lfanew decode).
9 Symlinked subdirectory: outside = real dir (UUID name) containing a real steam_appid.txt; root/linked -> outside; assert FolderMarkers.scan(root:) is empty.
10 Delay VA below ImageBase: delayUsesVA: true with no normal imports, patch DllNameRVA at PEFixture.rdataFileOffset + 4 to 0x1000 (< ImageBase 0x400000); parse succeeds, delayImports empty.
11 Nits: one readDescriptors(stride:nameOffset:isDelay:) helper (VA handling for delay), no unused imageBase param; Int(truncatingIfNeeded:) for UInt32->Int.
12 swift build (all products) + HubCoreTests green; report the final Test run line.
