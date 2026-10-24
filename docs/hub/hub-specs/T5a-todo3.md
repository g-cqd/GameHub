# T5a TO DO round 3 (verifier findings; all required; do items A and B FIRST). Worktree /Volumes/ExT2/GameHub/work/wt-hub-c.
A FolderMarkers.swift: replace the scan implementation with exactly this shape (adapt names, keep the public API `scan(root:) -> Set<String>` and `known`):
```swift
private struct DirIndex { let entries: [String: URL] }   // lowercased name -> URL, no stat
private static func index(_ dir: URL, budget: inout Int) -> DirIndex? {
  guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return nil }
  var map: [String: URL] = [:]
  for name in names.prefix(4096) { guard budget > 0 else { break }; budget -= 1
    let key = name.lowercased(); if map[key] == nil { map[key] = dir.appendingPathComponent(name) } }
  return DirIndex(entries: map)
}
private static func isReal(_ url: URL, directory: Bool?) -> Bool {   // lstat only for hits; symlinks never match
  var st = stat(); guard lstat(url.path, &st) == 0 else { return false }
  let type = st.st_mode & S_IFMT; if type == S_IFLNK { return false }
  if let d = directory { return d ? type == S_IFDIR : type != S_IFDIR }; return true
}
private static func matches(_ marker: String, in idx: DirIndex, budget: inout Int) -> Bool {
  let parts = marker.split(separator: "/").map { $0.lowercased() }
  guard let first = idx.entries[parts[0]] else { return false }
  if parts.count == 1 { return isReal(first, directory: nil) }
  guard isReal(first, directory: true), let sub = index(first, budget: &budget), let leaf = sub.entries[parts[1]] else { return false }
  return isReal(leaf, directory: nil)
}
package static func scan(root: URL) -> Set<String> {
  var budget = 4096 * 257; var found = Set<String>()
  guard let rootIdx = index(root, budget: &budget) else { return found }
  for m in known where matches(m.marker, in: rootIdx, budget: &budget) { found.insert(m.marker) }
  var dirs = 0
  for url in rootIdx.entries.values.sorted(by: { $0.path < $1.path }) {
    guard dirs < 256, budget > 0 else { break }
    guard isReal(url, directory: true) else { continue }; dirs += 1
    guard let sub = index(url, budget: &budget) else { continue }
    for m in known where !found.contains(m.marker) && matches(m.marker, in: sub, budget: &budget) { found.insert(m.marker) }
  }
  return found
}
```
B ExecutableFinder.swift walk: for each entry name: if it has a package extension (app, bundle, framework, plugin, kext) skip; else one call
`let v = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey, .isRegularFileKey, .fileSizeKey])`; `guard let v, v.isSymbolicLink == false else { continue }` (fail closed);
for non-directories apply the `.exe` + exclusion name filter BEFORE calling resourceValues (check the name first, then call resourceValues only for candidate files and for possible directories:
a name with an extension `.exe` -> candidate file; any other name -> resourceValues to learn if it is a directory); require `v.isRegularFile == true` for candidates; no `fileExists`.
C PEScanner.swift:226 regular-file check `(st.st_mode & S_IFMT) == S_IFREG`; test: `PEScanner.read` of a symlink to a valid PE throws `.invalid`.
D PEScanner: merge `readDelayImportDescriptors` into `readDescriptors(_ bytes:, rva:, imageBase:, stride:, nameOffset:, isDelay:)` (delay VA handling inside when isDelay); no unused params; `Int(truncatingIfNeeded:)` for UInt32 -> Int.
E Tests: the four 1025 tests assert the message contains "too many"; every reject test uses `guard case let .invalid(msg)? = (error as? HubError) else { Issue.record("wrong error \(error)"); return }` then `#expect(msg.contains(...))`.
F truncationNeverTraps: sectionTableEnd = PEFixture.peOffset + 24 + 224 + 2*40; for length in 0..<sectionTableEnd: `#expect(throws: (any Error).self) { try PEScanner.parse(Array(full.prefix(length))) }`; for the rest call parse and ignore the result.
G HubCoreTests green + full swift build.
