import Foundation
import Testing

@testable import QualityKit

@Suite struct GateTests {
    func quality(
        _ runner: FakeRunner,
        _ files: FakeFileSystem,
        aemi: URL? = aemiRoot,
        platform: Platform? = .macOSArm64
    ) -> Quality {
        Quality(
            workspace: workspace(aemi: aemi),
            runner: runner,
            fileSystem: files,
            reporter: FakeReporter(),
            platform: platform
        )
    }

    @Test func configMatchesAemisFiles() throws {
        let files = FakeFileSystem([
            "/aemi/.swift-format": "a", "/aemi/.swiftlint.yml": "b", "/pkg/.swift-format": "a",
            "/pkg/.swiftlint.yml": "b"
        ])
        try quality(FakeRunner(), files).run(.gate(.config))
        files.add("/pkg/.swiftlint.yml", "changed")
        #expect(
            throws: QualityError.gateFailed(
                ".swiftlint.yml differs from Aemi's; run  sh /aemi/scripts/sync-config.sh ."
            )
        ) {
            try quality(FakeRunner(), files).run(.gate(.config))
        }
    }

    @Test func aemiGatesNeedAemi() {
        for gate in [Gate.config, .manifest, .tags, .analyzers] {
            #expect(
                throws: QualityError.unavailable("Aemi isn't resolved: run with WINEKIT_DEV=1 (swift package resolve)")
            ) {
                try quality(FakeRunner(), FakeFileSystem(), aemi: nil).run(.gate(gate))
            }
        }
    }

    @Test func aemisScriptsRunWithTheirArguments() throws {
        let runner = FakeRunner()
        try quality(runner, FakeFileSystem()).run(.gate(.manifest))
        try quality(runner, FakeFileSystem()).run(.gate(.tags))
        #expect(
            runner.calls.map(\.arguments) == [
                ["/aemi/scripts/check-manifest-settings.sh", "Package.swift"], ["/aemi/scripts/check-tags.sh", "all"]
            ]
        )
    }

    @Test func aFailingCommandFailsItsGate() {
        let failing = FakeRunner { _ in CommandResult(status: 1) }
        #expect(throws: QualityError.gateFailed("formatting: run  swift-format format -i on the files above")) {
            try quality(failing, FakeFileSystem()).run(.gate(.format))
        }
        #expect(throws: QualityError.gateFailed("SwiftLint metrics")) {
            try quality(failing, FakeFileSystem()).run(.gate(.lint))
        }
        #expect(throws: QualityError.gateFailed("Package.swift settings")) {
            try quality(failing, FakeFileSystem()).run(.gate(.manifest))
        }
    }

    @Test func formatAndLintReadThePackage() throws {
        let runner = FakeRunner()
        try quality(runner, FakeFileSystem()).run(.gate(.format))
        try quality(runner, FakeFileSystem()).run(.gate(.lint))
        #expect(runner.calls[0].arguments == ["lint", "--strict", "-r", "Sources", "Tests", "Plugins", "Package.swift"])
        #expect(
            runner.calls[1].arguments == ["lint", "--strict", "--quiet", "--no-cache", "--config", ".swiftlint.yml"]
        )
        #expect(runner.calls.allSatisfy { $0.echo })
    }

    @Test func analyzersRunEveryPinnedToolOverTheCorpus() throws {
        let files = FakeFileSystem()
        installedAnalyzers(files)
        let runner = FakeRunner()
        try quality(runner, files).run(.gate(.analyzers))
        #expect(
            runner.calls.map { URL(fileURLWithPath: $0.executable).lastPathComponent } == [
                "deadwood", "dolly", "arcleak", "fcheck", "modeler"
            ]
        )
        #expect(
            runner.calls[0].arguments == [
                "analyze", "--strict", "--no-cache", "--relative-to", ".", "Sources", "Tests", "Plugins"
            ]
        )
        #expect(runner.calls[4].arguments == ["check", "--strict", "--no-cache", "--relative-to", ".", "Sources"])
    }

    @Test func everyAnalyzerRunsEvenAfterOneFails() {
        let files = FakeFileSystem()
        installedAnalyzers(files)
        let runner = FakeRunner {
            $0.executable.hasSuffix("dolly") || $0.executable.hasSuffix("fcheck")
                ? CommandResult(status: 1) : CommandResult(status: 0)
        }
        #expect(throws: QualityError.gateFailed("findings from dolly, fcheck")) {
            try quality(runner, files).run(.gate(.analyzers))
        }
        #expect(runner.calls.count == 5)
    }

    @Test func anAnalyzerMissingFromTheLockIsUnavailable() {
        let files = FakeFileSystem(["/aemi/scripts/analyzers.lock": "deadwood 1.0.0 \(sha) -"])
        files.add("/cache/deadwood-1.0.0/deadwood")
        #expect(throws: QualityError.unavailable("dolly is not in Aemi's lock")) {
            try quality(FakeRunner(), files).run(.gate(.analyzers))
        }
    }

    @Test func analyzersNeedAPublishedPlatform() {
        let files = FakeFileSystem()
        installedAnalyzers(files)
        #expect(throws: QualityError.unavailable("the analyzers publish macOS arm64 and Linux x86_64 archives only")) {
            try quality(FakeRunner(), files, platform: nil).run(.gate(.analyzers))
        }
    }

    @Test func testsRunInDebugThenReleaseInTheirOwnScratch() throws {
        let runner = FakeRunner()
        try quality(runner, FakeFileSystem()).run(.gate(.test))
        #expect(
            runner.calls.map(\.arguments) == [
                ["test", "--scratch-path", "/pkg/.build/quality", "--disable-sandbox"],
                [
                    "test", "-c", "release", "-Xswiftc", "-enable-testing", "--scratch-path", "/pkg/.build/quality",
                    "--disable-sandbox"
                ]
            ]
        )
    }

    @Test func aGivenToolchainReplacesTheOneOnPath() throws {
        var space = workspace()
        space.toolchain = URL(fileURLWithPath: "/tc/bin")
        let runner = FakeRunner()
        try Quality(
            workspace: space,
            runner: runner,
            fileSystem: FakeFileSystem(),
            reporter: FakeReporter(),
            platform: .macOSArm64
        )
        .run(.gate(.test))
        #expect(runner.calls.map(\.executable) == ["/tc/bin/swift", "/tc/bin/swift"])
        #expect(space.toolchainTool("swiftc") == "/tc/bin/swiftc")
        #expect(workspace().toolchainTool("swiftc") == "swiftc")
    }

    @Test func embeddedObjectsMayNeedLibcOnly() throws {
        let files = FakeFileSystem(["/pkg/Sources/HubRules/A.swift": "", "/pkg/Sources/HubRules/notes.md": ""])
        let clean = FakeRunner {
            $0.executable == "nm"
                ? CommandResult(status: 0, output: "                 U _free\n") : CommandResult(status: 0)
        }
        try quality(clean, files).run(.gate(.embedded))
        let compile = try #require(clean.calls(to: "swiftc").first)
        #expect(
            compile.arguments.contains("Sources/HubRules/A.swift")
                && !compile.arguments.contains("Sources/HubRules/notes.md")
        )
        let runtime = FakeRunner {
            $0.executable == "nm"
                ? CommandResult(status: 0, output: "                 U _swift_retain\n") : CommandResult(status: 0)
        }
        #expect(throws: QualityError.gateFailed("HubRules needs _swift_retain, outside libc")) {
            try quality(runtime, files).run(.gate(.embedded))
        }
    }

    @Test func libraryTargetsAreTheSourceDirectoriesWithoutAMain() {
        let files = FakeFileSystem([
            "/pkg/Sources/HubRules/A.swift": "", "/pkg/Sources/tool/main.swift": "",
            "/pkg/Sources/QualityKit/B.swift": ""
        ])
        #expect(quality(FakeRunner(), files).libraryTargets == ["HubRules", "QualityKit"])
    }

    func mutationFiles(baseline: Bool) -> FakeFileSystem {
        let files = FakeFileSystem([
            "/pkg/Quality/tools.lock": "swift-mutation-testing 1.6.4 \(sha) -",
            "/cache/swift-mutation-testing-1.6.4/swift-mutation-testing": "",
            "/pkg/Sources/HubRules/A.swift": "", "/pkg/Sources/HubRules/B.swift": "",
            "/pkg/Sources/tool/main.swift": "",
            reportPath: mutationReport()
        ])
        if baseline { files.add("/pkg/.swift-mutation-testing-baseline.json", "{}") }
        return files
    }

    @Test func aFullMutationRunMutatesEverythingWithoutCache() throws {
        let runner = FakeRunner()
        try quality(runner, mutationFiles(baseline: true)).run(.gate(.mutation))
        let call = try #require(runner.calls.first)
        #expect(call.executable == "env")
        #expect(
            call.arguments.prefix(3) == [
                "-u", "WINEKIT_DEV", "/cache/swift-mutation-testing-1.6.4/swift-mutation-testing"
            ]
        )
        let arguments = call.arguments
        #expect(arguments.contains("--no-cache") && !arguments.contains("--exclude"))
        #expect(
            arguments.suffix(4) == ["--baseline", ".swift-mutation-testing-baseline.json", "--max-new-survivors", "0"]
        )
    }

    @Test func aScopedMutationRunExcludesTheRestAndKeepsTheCache() throws {
        let runner = FakeRunner()
        try quality(runner, mutationFiles(baseline: false))
            .mutation(.changed(["Sources/HubRules/A.swift"]))
        let arguments = try #require(runner.calls.first).arguments
        #expect(!arguments.contains("--no-cache") && !arguments.contains("--baseline"))
        // every other source is excluded, the executable's included: the command line replaces the configuration's list
        #expect(
            arguments.suffix(4) == ["--exclude", "/Sources/HubRules/B.swift", "--exclude", "/Sources/tool/main.swift"]
        )
    }

    @Test func writingTheBaselineRunsEverythingAndRecordsIt() throws {
        let runner = FakeRunner()
        try quality(runner, mutationFiles(baseline: true)).run(.mutationBaseline)
        let arguments = try #require(runner.calls.first).arguments
        #expect(arguments.suffix(2) == ["--write-baseline", ".swift-mutation-testing-baseline.json"])
        #expect(!arguments.contains("--baseline") && arguments.contains("--no-cache"))
    }

    @Test func mutationNeedsMacOSAndItsLock() {
        #expect(throws: QualityError.unavailable("swift-mutation-testing is published for macOS arm64 only")) {
            try quality(FakeRunner(), mutationFiles(baseline: false), platform: .linuxX86).run(.gate(.mutation))
        }
        let noTool = FakeFileSystem(["/pkg/Quality/tools.lock": "other 1.0.0 \(sha) -"])
        #expect(throws: QualityError.unavailable("swift-mutation-testing is not in Quality/tools.lock")) {
            try quality(FakeRunner(), noTool).run(.gate(.mutation))
        }
    }
}
