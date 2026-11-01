public import Foundation

/// One check.
public enum Gate: String, CaseIterable, Sendable {
    /// .swift-format and .swiftlint.yml are Aemi's canonical ones, unchanged (Aemi's scripts/sync-config.sh copies them).
    case config
    /// Package.swift has the family's canonical compiler settings (Aemi's scripts/check-manifest-settings.sh).
    case manifest
    /// No work-in-progress markers or planning shorthand in the sources (Aemi's scripts/check-tags.sh).
    case tags
    /// swift-format lint --strict.
    case format
    /// SwiftLint's size and complexity metrics, --strict.
    case lint
    /// deadwood, dolly, arcleak, fcheck and modeler, pinned in Aemi's scripts/analyzers.lock.
    case analyzers
    /// The suite in debug (bounds checks live), then in release.
    case test
    /// The libraries Wine links compile as Embedded Swift for its x86_64 Unix side, needing libc only.
    case embedded
    /// Byte-identical output against Wine's C implementation.
    case differential
    /// swift-mutation-testing over the library sources.
    case mutation
}

/// What the command line asked for.
public enum Request: Equatable, Sendable {
    case gate(Gate)
    /// The static gates over the whole package.
    case fast
    /// Everything but mutation testing, over the whole package.
    case all
    /// Every gate, scoped to the files a commit or a push changes.
    case changed(Hook)
    /// A full mutation run that records its undetected mutants as the accepted baseline. Each one needs its reason in
    /// docs/mutation-baseline.md: only an equivalent mutant (one no input can tell apart) belongs there.
    case mutationBaseline

    public static let fastGates: [Gate] = [.config, .manifest, .tags, .format, .lint, .analyzers]
    public static let allGates: [Gate] = fastGates + [.test, .embedded, .differential]

    public static let usage =
        "usage: quality <\(Gate.allCases.map(\.rawValue).joined(separator: "|"))|fast|all|mutation-baseline>"
        + " | quality changed <pre-commit|pre-push>"

    public static func parse(_ arguments: [String]) throws -> Request {
        switch arguments.first {
            case "fast" where arguments.count == 1: return .fast
            case "all" where arguments.count == 1: return .all
            case "mutation-baseline" where arguments.count == 1: return .mutationBaseline
            case "changed" where arguments.count == 2:
                guard let hook = Hook(rawValue: arguments[1]) else { throw QualityError.usage(usage) }
                return .changed(hook)
            case let name? where arguments.count == 1:
                guard let gate = Gate(rawValue: name) else { throw QualityError.usage(usage) }
                return .gate(gate)
            default: throw QualityError.usage(usage)
        }
    }
}

/// Where things are.
public struct Workspace: Equatable, Sendable {
    /// The package directory.
    public var root: URL
    /// The pinned Aemi checkout (resolved with WINEKIT_DEV=1), for its scripts and canonical configuration.
    public var aemi: URL?
    /// Where pinned tools are installed.
    public var toolCache: URL
    /// A Wine checkout holding dlls/ntdll/unix/hubrules.c, for the differential test.
    public var wineSource: URL?
    /// The toolchain's bin directory, for swift and swiftc. The plugin passes the one running it: `swift` on PATH may be a
    /// toolchain manager's proxy, which wants the network to check its toolchain.
    public var toolchain: URL?

    public init(root: URL, aemi: URL?, toolCache: URL, wineSource: URL?, toolchain: URL? = nil) {
        self.root = root
        self.aemi = aemi
        self.toolCache = toolCache
        self.wineSource = wineSource
        self.toolchain = toolchain
    }

    /// `swift`, `swiftc`: from the toolchain when one was given, else from PATH.
    public func toolchainTool(_ name: String) -> String {
        toolchain.map { $0.appendingPathComponent(name).path } ?? name
    }

    /// Nested builds use their own scratch directory: the `swift package` that runs the plugin holds the lock on .build.
    public var scratch: URL { root.appendingPathComponent(".build/quality") }

    /// The options of a nested `swift build` or `swift test`: its own scratch directory, and no manifest sandbox, since
    /// macOS doesn't allow a sandbox inside the plugin's.
    public var nestedBuildArguments: [String] { ["--scratch-path", scratch.path, "--disable-sandbox"] }

    /// The libraries Wine links: compiled as Embedded Swift.
    public static let embeddedTargets = ["HubRules"]
    /// The paths the analyzers read.
    public static let corpus = ["Sources", "Tests", "Plugins"]
    /// The paths swift-format and SwiftLint read.
    public static let swiftPaths = ["Sources", "Tests", "Plugins", "Package.swift"]
    /// Aemi's canonical configuration files.
    public static let configs = [".swift-format", ".swiftlint.yml"]
}

/// Runs gates.
public struct Quality: Sendable {
    let workspace: Workspace
    let runner: any CommandRunning
    let fileSystem: any FileSystem
    let reporter: any Reporting
    let platform: Platform?

    public init(
        workspace: Workspace,
        runner: any CommandRunning,
        fileSystem: any FileSystem,
        reporter: any Reporting,
        platform: Platform?
    ) {
        self.workspace = workspace
        self.runner = runner
        self.fileSystem = fileSystem
        self.reporter = reporter
        self.platform = platform
    }

    public func run(_ request: Request) throws {
        switch request {
            case .gate(let gate): try run(gate)
            case .fast: for gate in Request.fastGates { try run(gate) }
            case .all: for gate in Request.allGates { try run(gate) }
            case .changed(let hook): try runChanged(hook)
            case .mutationBaseline: try mutation(.full(writeBaseline: true))
        }
    }

    func run(_ gate: Gate) throws {
        switch gate {
            case .config: try config()
            case .manifest:
                try aemiScript("check-manifest-settings.sh", ["Package.swift"], failure: "Package.swift settings")
            case .tags: try aemiScript("check-tags.sh", ["all"], failure: "tags")
            case .format: try format(Workspace.swiftPaths, recursive: true)
            case .lint: try lint(nil)
            case .analyzers: try analyzers(onlyFrom: nil)
            case .test: try test(release: true)
            case .embedded: try embedded()
            case .differential: try differential()
            case .mutation: try mutation(.full(writeBaseline: false))
        }
    }

    /// The library targets: Sources/<target>/ without a main.swift.
    var libraryTargets: [String] {
        let files = fileSystem.files(under: workspace.root.appendingPathComponent("Sources"))
        let targets = Set(files.compactMap { $0.split(separator: "/").first.map(String.init) })
        let executables = Set(
            files.filter { $0.hasSuffix("/main.swift") }.compactMap { $0.split(separator: "/").first }
        )
        return targets.filter { !executables.contains(Substring($0)) }.sorted()
    }

    /// The Swift sources of a target, as paths from the package root.
    func swiftSources(of target: String) -> [String] {
        fileSystem.files(under: workspace.root.appendingPathComponent("Sources/\(target)"))
            .filter { $0.hasSuffix(".swift") }.map { "Sources/\(target)/\($0)" }
    }

    /// Runs a helper command (rm, mkdir, cp) quietly in the package, and fails with `failure` when it does.
    func helper(_ executable: String, _ arguments: [String], failure: String) throws {
        let result = try runner.run(executable, arguments, in: workspace.root, echo: false)
        guard result.succeeded else { throw QualityError.unavailable("\(failure): \(result.errors.trimmed)") }
    }

    /// Runs `executable` in the package and fails the gate with `failure` when it does.
    func gate(_ executable: String, _ arguments: [String], failure: String) throws {
        let result = try runner.run(executable, arguments, in: workspace.root, echo: true)
        guard result.succeeded else { throw QualityError.gateFailed(failure) }
    }

    func aemiDirectory() throws -> URL {
        guard let aemi = workspace.aemi else {
            throw QualityError.unavailable("Aemi isn't resolved: run with WINEKIT_DEV=1 (swift package resolve)")
        }
        return aemi
    }

    func aemiScript(_ name: String, _ arguments: [String], failure: String) throws {
        let script = try aemiDirectory().appendingPathComponent("scripts/\(name)")
        reporter.step("\(name) \(arguments.joined(separator: " "))")
        try gate("sh", [script.path] + arguments, failure: failure)
    }
}
