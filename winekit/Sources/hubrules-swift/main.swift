// hubrules-swift <rules-file> <executable> [launcher-compatdb-file]
// Prints what hub_rules_apply would do for the executable: the WINE_COMPATDB value, then the capabilities. The output format
// is the one of the C harness in Scripts/differential.sh, so the two can be compared byte for byte.
import Foundation
import HubRules

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write(
        Data("usage: hubrules-swift <rules-file> <executable> [launcher-compatdb-file]\n".utf8)
    )
    exit(2)
}

func contents(_ path: String) -> Bytes {
    (try? Data(contentsOf: URL(fileURLWithPath: path))).map { Bytes($0) } ?? []
}

struct FileOnDisk: PEFile {
    let handle: FileHandle?
    func read(at offset: Int, count: Int) -> Bytes {
        guard let handle, offset >= 0, count > 0 else { return [] }
        do {
            try handle.seek(toOffset: UInt64(offset))
            return Bytes(try handle.read(upToCount: count) ?? Data())
        } catch { return [] }
    }
}

let rules = Bytes(contents(arguments[1]).prefix(256 * 1024))
let exePath = arguments[2]
let exe = Bytes((exePath.split(separator: "/").last.map(String.init) ?? exePath).utf8)
let launcher = arguments.count > 3 ? contents(arguments[3]) : []
let facts = PEFacts.read(from: FileOnDisk(handle: FileHandle(forReadingAtPath: exePath)))
let result = RulesEngine.apply(rules: rules, exe: exe, facts: facts, launcher: launcher)

var out = Data(result.compatDB)
out.append(Data("\n--\ngate_selector_fixup=\(result.gateSelectorFixup ? 1 : 0)\n".utf8))
out.append(Data("hub_dll_dir=".utf8))
out.append(Data(result.dllDirectory ?? []))
out.append(Data("\n".utf8))
FileHandle.standardOutput.write(out)
