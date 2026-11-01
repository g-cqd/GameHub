import Foundation
import Synchronization

@testable import QualityKit

/// Records every command and answers from `respond`, or with success.
final class FakeRunner: CommandRunning {
    struct Call: Equatable {
        var executable: String
        var arguments: [String]
        var echo: Bool
    }

    private let state = Mutex<[Call]>([])
    let respond: @Sendable (Call) -> CommandResult

    init(respond: @escaping @Sendable (Call) -> CommandResult = { _ in CommandResult(status: 0) }) {
        self.respond = respond
    }

    var calls: [Call] { state.withLock { $0 } }

    func run(_ executable: String, _ arguments: [String], in directory: URL, echo: Bool) throws -> CommandResult {
        let call = Call(executable: executable, arguments: arguments, echo: echo)
        state.withLock { $0.append(call) }
        let result = respond(call)
        // As ProcessRunner: an echoed command's output goes to the terminal and isn't captured.
        return echo ? CommandResult(status: result.status) : result
    }

    /// The calls whose executable ends with `name`.
    func calls(to name: String) -> [Call] { calls.filter { $0.executable.hasSuffix(name) } }
}

/// Files in memory, by absolute path.
final class FakeFileSystem: FileSystem {
    private let state: Mutex<[String: Data]>

    init(_ files: [String: String] = [:]) {
        state = Mutex(files.mapValues { Data($0.utf8) })
    }

    func add(_ path: String, _ text: String = "") { state.withLock { $0[path] = Data(text.utf8) } }

    func fileExists(_ url: URL) -> Bool { state.withLock { $0[url.path] != nil } }

    func contents(_ url: URL) throws -> Data {
        guard let data = state.withLock({ $0[url.path] }) else { throw CocoaError(.fileNoSuchFile) }
        return data
    }

    func files(under directory: URL) -> [String] {
        let base = directory.path + "/"
        return state.withLock { $0.keys.filter { $0.hasPrefix(base) }.map { String($0.dropFirst(base.count)) } }
            .sorted()
    }

    func write(_ data: Data, to url: URL) throws { state.withLock { $0[url.path] = data } }

    func text(_ path: String) -> String? { state.withLock { $0[path].map { String(decoding: $0, as: UTF8.self) } } }
}

final class FakeReporter: Reporting {
    private let state = Mutex<[String]>([])
    var lines: [String] { state.withLock { $0 } }
    func step(_ message: String) { state.withLock { $0.append("==> \(message)") } }
    func note(_ message: String) { state.withLock { $0.append(message) } }
}

let root = URL(fileURLWithPath: "/pkg")
let aemiRoot = URL(fileURLWithPath: "/aemi")
let toolCache = URL(fileURLWithPath: "/cache")
let wineRoot = URL(fileURLWithPath: "/wine")

func workspace(aemi: URL? = aemiRoot, wine: URL? = wineRoot) -> Workspace {
    Workspace(root: root, aemi: aemi, toolCache: toolCache, wineSource: wine)
}

let sha = String(repeating: "a", count: 64)
let otherSHA = String(repeating: "b", count: 64)

/// A mutation report, as swift-mutation-testing writes it, with one mutant per (path, status, fingerprint).
func mutationReport(_ mutants: [(path: String, status: String, fingerprint: String)] = []) -> String {
    let files = Dictionary(grouping: mutants, by: \.path)
        .map { path, list in
            let entries = list.map {
                """
                {"fingerprint": "\($0.fingerprint)", "status": "\($0.status)", "mutatorName": "RelationalOperatorReplacement",
                 "description": "< → <=", "location": {"start": {"line": 15, "column": 3}, "end": {"line": 15, "column": 4}}}
                """
            }
            return "\"\(path)\": {\"mutants\": [\(entries.joined(separator: ","))]}"
        }
    return "{\"files\": {\(files.joined(separator: ","))}, \"schemaVersion\": \"1\"}"
}

let reportPath = "/pkg/.build/quality/mutation-report.json"

/// Aemi's lock with every analyzer at version 1.0.0, all already installed in `files`.
func installedAnalyzers(_ files: FakeFileSystem) {
    let tools = ["deadwood", "dolly", "arcleak", "fcheck", "modeler"]
    files.add("/aemi/scripts/analyzers.lock", tools.map { "\($0) 1.0.0 \(sha) \(sha)" }.joined(separator: "\n"))
    for tool in tools { files.add("/cache/\(tool)-1.0.0/\(tool)") }
}
