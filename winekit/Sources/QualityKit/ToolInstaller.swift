public import Foundation

public enum Platform: Sendable {
    case macOSArm64
    case linuxX86

    public static var current: Platform? {
        #if os(macOS) && arch(arm64)
            .macOSArm64
        #elseif os(Linux) && arch(x86_64)
            .linuxX86
        #else
            nil
        #endif
    }
}

/// Where a tool's release archives are published, and how they are named.
public enum ReleaseSource: Sendable {
    /// github.com/g-cqd/<tool>: `<tool>-<version>-<platform>.tar.gz`, holding a `<tool>-<version>-<platform>/` directory.
    case gcqd
    /// github.com/ericodx/swift-mutation-testing: `swift-mutation-testing-v<version>-macos.tar.gz`.
    case swiftMutationTesting

    func archiveName(_ tool: PinnedTool, _ platform: Platform) -> String {
        switch self {
            case .gcqd:
                "\(tool.name)-\(tool.version)-\(platform == .macOSArm64 ? "macos-arm64" : "linux-x86_64").tar.gz"
            case .swiftMutationTesting: "swift-mutation-testing-v\(tool.version)-macos.tar.gz"
        }
    }

    func url(_ tool: PinnedTool, _ platform: Platform) -> String {
        let repository =
            switch self {
                case .gcqd: "g-cqd/\(tool.name)"
                case .swiftMutationTesting: "ericodx/swift-mutation-testing"
            }
        return "https://github.com/\(repository)/releases/download/v\(tool.version)/\(archiveName(tool, platform))"
    }
}

/// Installs pinned tools into a cache outside the repository. An archive whose hash isn't the pinned one, or a binary that
/// doesn't report the pinned version, is refused: baseline fingerprints move between versions, so an unpinned tool would
/// turn a gate red with no change of ours.
public struct ToolInstaller: Sendable {
    let runner: any CommandRunning
    let fileSystem: any FileSystem
    let cache: URL
    let platform: Platform

    public init(runner: any CommandRunning, fileSystem: any FileSystem, cache: URL, platform: Platform) {
        self.runner = runner
        self.fileSystem = fileSystem
        self.cache = cache
        self.platform = platform
    }

    /// Where the installer's commands run: every path they take is absolute, and the cache may not exist yet.
    static let anywhere = URL(fileURLWithPath: "/")

    public func directory(for tool: PinnedTool) -> URL {
        cache.appendingPathComponent("\(tool.name)-\(tool.version)")
    }

    /// The tool's executable, installed first if it isn't yet.
    public func executable(for tool: PinnedTool, from source: ReleaseSource) throws -> URL {
        let installed = directory(for: tool).appendingPathComponent(tool.name)
        if fileSystem.fileExists(installed) { return installed }
        let sha = platform == .macOSArm64 ? tool.macOSArm64SHA : tool.linuxX86SHA
        guard let sha else { throw QualityError.unavailable("\(tool.name) publishes no archive for this platform") }

        let scratch = cache.appendingPathComponent(".download-\(tool.name)-\(tool.version)").path
        let archive = scratch + "/" + source.archiveName(tool, platform)
        try step("clean \(scratch)", "rm", "-rf", scratch)
        try step("create \(scratch)", "mkdir", "-p", scratch)
        defer { _ = try? runner.run("rm", ["-rf", scratch], in: Self.anywhere, echo: false) }

        try step(
            "download \(tool.name) \(tool.version)",
            "curl",
            "-fsSL",
            "--retry",
            "3",
            "-o",
            archive,
            source.url(tool, platform)
        )
        let actual =
            try step("hash", "shasum", "-a", "256", archive).output.split(separator: " ").first.map(String.init) ?? ""
        guard actual == sha else {
            throw QualityError.unavailable("\(tool.name): archive hash \(actual) is not the pinned \(sha)")
        }
        try step("unpack", "tar", "-xzf", archive, "-C", scratch)

        // The binary's directory goes whole: the Linux archives carry the Swift runtime libraries beside it.
        let files = fileSystem.files(under: URL(fileURLWithPath: scratch))
        guard let binary = files.first(where: { URL(fileURLWithPath: $0).lastPathComponent == tool.name }) else {
            throw QualityError.unavailable("\(tool.name): no binary in the archive")
        }
        let target = directory(for: tool).path
        try step("create \(target)", "mkdir", "-p", target)
        try step(
            "install",
            "cp",
            "-R",
            URL(fileURLWithPath: scratch + "/" + binary).deletingLastPathComponent().path + "/.",
            target
        )

        let reported = try runner.run(installed.path, ["--version"], in: Self.anywhere, echo: false)
        guard reported.succeeded, reported.output.contains(tool.version) else {
            _ = try? runner.run("rm", ["-rf", target], in: Self.anywhere, echo: false)
            throw QualityError.unavailable("\(tool.name) reports '\(reported.output.trimmed)', not \(tool.version)")
        }
        return installed
    }

    /// Runs one installation step; `what` names it when it fails.
    @discardableResult
    private func step(_ what: String, _ executable: String, _ arguments: String...) throws -> CommandResult {
        let result = try runner.run(executable, arguments, in: Self.anywhere, echo: false)
        guard result.succeeded else { throw QualityError.unavailable("could not \(what): \(result.errors.trimmed)") }
        return result
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
