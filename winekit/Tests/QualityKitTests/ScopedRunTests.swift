import Foundation
import Testing

@testable import QualityKit

@Suite struct ScopedRunTests {
    /// A package with one library source, one tool, the analyzers and swift-mutation-testing installed, and git answering
    /// `diff` with `changed` (and `@{upstream}` with `upstream`, when given).
    func setUp(changed: [String], upstream: String? = nil) -> (Quality, FakeRunner, FakeFileSystem) {
        let files = FakeFileSystem([
            "/pkg/Sources/HubRules/A.swift": "", "/pkg/Sources/QualityKit/Q.swift": "",
            "/pkg/Sources/tool/main.swift": "",
            "/pkg/Quality/tools.lock": "swift-mutation-testing 1.6.4 \(sha) -",
            "/cache/swift-mutation-testing-1.6.4/swift-mutation-testing": ""
        ])
        installedAnalyzers(files)
        let runner = FakeRunner { call in
            guard call.executable == "git" else { return CommandResult(status: 0) }
            if call.arguments.contains("@{upstream}") {
                return upstream.map { CommandResult(status: 0, output: "\($0)\n") } ?? CommandResult(status: 1)
            }
            return CommandResult(status: 0, output: changed.joined(separator: "\n"))
        }
        let quality = Quality(
            workspace: workspace(wine: nil), runner: runner, fileSystem: files, reporter: FakeReporter(),
            platform: .macOSArm64)
        return (quality, runner, files)
    }

    func tools(_ runner: FakeRunner) -> [String] {
        runner.calls.map { ($0.executable as NSString).lastPathComponent }.filter { !["git", "mkdir"].contains($0) }
    }

    @Test func nothingChangedRunsNothing() throws {
        let (quality, runner, _) = setUp(changed: [])
        try quality.run(.changed(.preCommit))
        #expect(tools(runner).isEmpty)
    }

    @Test func aCommitOfALibrarySourceRunsEveryGateOnIt() throws {
        let (_, runner, files) = setUp(changed: ["Sources/HubRules/A.swift"])
        for (path, text) in [
            ("/wine/dlls/ntdll/unix/hubrules.c", ""), ("/pkg/Differential/rules/a.txt", ""),
            ("/pkg/Differential/executables", "$ROOT/Sources/tool/main.swift\n")
        ] { files.add(path, text) }
        let quality = Quality(
            workspace: workspace(), runner: runner, fileSystem: files, reporter: FakeReporter(), platform: .macOSArm64)
        try quality.run(.changed(.preCommit))
        let order = [
            "sh", "swift-format", "swiftlint", "deadwood", "dolly", "arcleak", "fcheck", "modeler", "swift", "swiftc",
            "nm", "clang",
            "harness", "hubrules-swift", "env"
        ]
        let ran = tools(runner)
        #expect(order.compactMap { ran.firstIndex(of: $0) } == order.compactMap { ran.firstIndex(of: $0) }.sorted())
        #expect(order.allSatisfy { ran.contains($0) })
        #expect(runner.calls(to: "sh").first?.arguments == ["/aemi/scripts/check-tags.sh", "staged"])
        #expect(runner.calls(to: "swift-format").first?.arguments == ["lint", "--strict", "Sources/HubRules/A.swift"])
        #expect(
            runner.calls(to: "swiftlint").first?.arguments.suffix(2) == ["--force-exclude", "Sources/HubRules/A.swift"])
        #expect(runner.calls(to: "deadwood").first?.arguments.contains("/pkg/.build/quality/changed-files") == true)
        #expect(files.text("/pkg/.build/quality/changed-files") == "Sources/HubRules/A.swift\n")
        // debug only before a commit
        #expect(runner.calls(to: "swift").filter { $0.arguments.first == "test" }.count == 1)
        let mutation = try #require(runner.calls(to: "env").first).arguments
        #expect(mutation.suffix(2) == ["--exclude", "/Sources/QualityKit/Q.swift"])
    }

    @Test func aPushComparesWithTheUpstreamAndTestsInReleaseToo() throws {
        let (quality, runner, _) = setUp(changed: ["Sources/QualityKit/Q.swift"], upstream: "origin/topic")
        try quality.run(.changed(.prePush))
        #expect(runner.calls(to: "git").last?.arguments.contains("origin/topic...HEAD") == true)
        #expect(runner.calls(to: "swift").count == 2)
        #expect(runner.calls(to: "sh").isEmpty)  // the staged-tags check belongs to commits
        #expect(runner.calls(to: "swiftc").isEmpty)  // QualityKit is a host tool, not Embedded
    }

    @Test func aPushWithoutUpstreamComparesWithOriginMain() throws {
        let (quality, runner, _) = setUp(changed: ["README.md"])
        try quality.run(.changed(.prePush))
        #expect(runner.calls(to: "git").last?.arguments.contains("origin/main...HEAD") == true)
        // no Swift, no manifest, nothing the differential reads
        #expect(tools(runner).isEmpty)
    }

    @Test func aManifestOrConfigChangeRunsTheirGates() throws {
        let (quality, runner, files) = setUp(changed: ["Package.swift", ".swiftlint.yml"])
        for name in Workspace.configs {
            files.add("/aemi/\(name)", "same")
            files.add("/pkg/\(name)", "same")
        }
        try quality.run(.changed(.prePush))
        #expect(
            runner.calls(to: "sh").first?.arguments == ["/aemi/scripts/check-manifest-settings.sh", "Package.swift"])
        #expect(runner.calls(to: "swift-format").first?.arguments.last == "Package.swift")
    }

    @Test func aFailedGitDiffIsUnavailable() {
        let runner = FakeRunner { _ in CommandResult(status: 128, errors: "not a git repository\n") }
        let quality = Quality(
            workspace: workspace(), runner: runner, fileSystem: FakeFileSystem(), reporter: FakeReporter())
        #expect(throws: QualityError.unavailable("git diff failed: not a git repository")) {
            try quality.run(.changed(.preCommit))
        }
    }
}
