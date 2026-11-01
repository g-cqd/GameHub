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
                ".swiftlint.yml differs from Aemi's; run  sh /aemi/Scripts/sync-config.sh ."
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
                ["/aemi/Scripts/check-manifest-settings.sh", "Package.swift"], ["/aemi/Scripts/check-tags.sh", "all"]
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
        let files = FakeFileSystem(["/aemi/Scripts/analyzers.lock": "deadwood 1.0.0 \(sha) -"])
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
        let clean = FakeRunner()
        try quality(clean, files).run(.gate(.embedded))
        let compile = try #require(clean.calls(to: "swiftc").last)
        #expect(
            compile.arguments.contains("Sources/HubRules/A.swift")
                && !compile.arguments.contains("Sources/HubRules/notes.md")
        )
        let runtime = FakeRunner {
            $0.executable == "nm" ? CommandResult(status: 0, output: "                 U _swift_retain\n") : fine($0)
        }
        #expect(throws: QualityError.gateFailed("libwinekit.a needs _swift_retain, outside libc")) {
            try quality(runtime, files).run(.gate(.embedded))
        }
        // a symbol one object needs and another defines stays inside the archive
        let kernels = FakeRunner {
            $0.executable == "nm"
                ? CommandResult(
                    status: 0,
                    output: goodNM + "                 U _adf_scan\n0000000000000020 T _adf_scan\n"
                )
                : fine($0)
        }
        try quality(kernels, files).run(.gate(.embedded))
    }

    @Test func theLibraryMustDefineWhatTheHeaderDeclares() {
        let files = FakeFileSystem(["/pkg/Sources/HubRules/A.swift": ""])
        let partial = FakeRunner {
            $0.executable == "nm" ? CommandResult(status: 0, output: "0000000000000010 T _winekit_free\n") : fine($0)
        }
        #expect(
            throws: QualityError.gateFailed("winekit.h declares _winekit_hub_rules_apply, which no library defines")
        ) {
            try quality(partial, files).run(.gate(.embedded))
        }
    }

    @Test func wineObjectsArchiveTheObjectsAndCopyTheHeader() throws {
        let files = FakeFileSystem(["/pkg/Sources/HubRules/A.swift": ""])
        let runner = FakeRunner()
        try quality(runner, files).run(.wineObjects(output: "/out"))
        #expect(
            runner.calls(to: "ar").first?.arguments == [
                "rcs", "/out/libwinekit.a", "/out/aemi/adf_cpu_features.o", "/out/aemi/adf_scan.o",
                "/out/aemi/AemiKernels.o", "/out/aemi/AemiKernel.o", "/out/HubRules.o"
            ]
        )
        // Aemi's C, with its flags and includes from c-targets.sh, then its modules, each on the next one's path
        let c = runner.calls(to: "clang").map(\.arguments)
        #expect(
            c.first == [
                "-target", "x86_64-apple-macos15", "-O2", "-fno-stack-protector", "-std=c11", "-Werror",
                "-I/aemi/Sources/CAemiCPU/include", "-I/aemi/Sources/CAemiKernels/include",
                "-c", "/aemi/Sources/CAemiCPU/adf_cpu_features.c", "-o", "/out/aemi/adf_cpu_features.o"
            ]
        )
        let swiftc = runner.calls(to: "swiftc").map(\.arguments)
        #expect(swiftc.count == 3)
        #expect(swiftc[0].contains("-emit-module-path") && swiftc[0].contains("/out/aemi/AemiKernels.swiftmodule"))
        #expect(swiftc[1].contains("/out/aemi") && swiftc[1].contains("/out/aemi/AemiKernel.swiftmodule"))
        #expect(!swiftc[2].contains("-emit-module") && swiftc[2].contains("/out/aemi"))
        #expect(runner.calls(to: "cp").first?.arguments == ["/pkg/C/winekit.h", "/out"])
        #expect(runner.calls(to: "rm").first?.arguments == ["-f", "/out/libwinekit.a"])
        let compile = try #require(runner.calls(to: "swiftc").last).arguments
        #expect(compile.suffix(3) == ["-emit-object", "-o", "/out/HubRules.o"])
        #expect(compile.contains("-disable-stack-protector"))
    }

    @Test func aemisCTargetsAreReadFromItsScript() throws {
        let files = FakeFileSystem(["/pkg/Sources/HubRules/A.swift": ""])
        let runner = FakeRunner()
        try quality(runner, files).run(.gate(.embedded))
        let read = try #require(runner.calls(to: "sh").first)
        #expect(read.arguments == ["-c", EmbeddedCheck.cTargetsScript, "sh", "/aemi"] && !read.echo)
        let broken = FakeRunner {
            $0.executable == "sh" ? CommandResult(status: 2, errors: "no c-targets.sh") : fine($0)
        }
        #expect(throws: QualityError.unavailable("could not read Aemi's Scripts/lib/c-targets.sh: no c-targets.sh")) {
            try quality(broken, files).run(.gate(.embedded))
        }
        #expect(EmbeddedCheck.CTargets(scriptOutput: "\n\n\n") == nil)
        #expect(EmbeddedCheck.CTargets(scriptOutput: "-O2\n") == nil)
        #expect(EmbeddedCheck.CTargets(scriptOutput: "-O2\n-I/x\n/a.c /b.c\n")?.sources == ["/a.c", "/b.c"])
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
            "/pkg/Sources/QualityKit/Q.swift": "", "/pkg/Sources/tool/main.swift": "", reportPath: mutationReport()
        ])
        if baseline { files.add("/pkg/.swift-mutation-testing-baseline.json", "{\"undetected\": []}") }
        return files
    }

    /// The mutation tool's call: taskpolicy -b env -u WINEKIT_DEV <tool> <arguments>.
    func mutationCall(_ runner: FakeRunner) throws -> [String] {
        let call = try #require(runner.calls(to: "taskpolicy").first)
        #expect(
            call.arguments.prefix(5) == [
                "-b", "env", "-u", "WINEKIT_DEV", "/cache/swift-mutation-testing-1.6.4/swift-mutation-testing"
            ]
        )
        return Array(call.arguments.dropFirst(5))
    }

    @Test func aFullRunMutatesTheCodeWineRunsOnTheEfficiencyCores() throws {
        let runner = FakeRunner { $0.executable == "sysctl" ? CommandResult(status: 0, output: "4\n") : fine($0) }
        try quality(runner, mutationFiles(baseline: true)).run(.gate(.mutation))
        let arguments = try mutationCall(runner)
        #expect(
            arguments.contains("--no-cache") && !arguments.contains("--baseline")
                && !arguments.contains("--write-baseline")
        )
        #expect(
            arguments.contains("--operator-tier")
                && arguments[arguments.firstIndex(of: "--operator-tier")! + 1] == "default"
        )
        #expect(arguments[arguments.firstIndex(of: "--concurrency")! + 1] == "4")
        // HubRules is mutated; QualityKit and the executables are not
        #expect(
            arguments.suffix(4) == ["--exclude", "/Sources/QualityKit/Q.swift", "--exclude", "/Sources/tool/main.swift"]
        )
    }

    @Test func aScopedRunMutatesOnlyTheChangedCodeWineRunsAndKeepsTheCache() throws {
        let runner = FakeRunner()
        try quality(runner, mutationFiles(baseline: false))
            .mutation(.changed(["Sources/HubRules/A.swift", "Sources/QualityKit/Q.swift"]))
        let arguments = try mutationCall(runner)
        #expect(!arguments.contains("--no-cache"))
        #expect(
            arguments.suffix(6) == [
                "--exclude", "/Sources/HubRules/B.swift", "--exclude", "/Sources/QualityKit/Q.swift", "--exclude",
                "/Sources/tool/main.swift"
            ]
        )
    }

    @Test func aChangeOutsideTheCodeWineRunsMutatesNothing() throws {
        let runner = FakeRunner()
        try quality(runner, mutationFiles(baseline: false)).mutation(.changed(["Sources/QualityKit/Q.swift"]))
        #expect(runner.calls(to: "taskpolicy").isEmpty)
    }

    @Test func writingTheBaselineRunsEverythingAndRecordsIt() throws {
        let runner = FakeRunner()
        try quality(runner, mutationFiles(baseline: true)).run(.mutationBaseline)
        let arguments = try mutationCall(runner)
        #expect(
            arguments.contains("--write-baseline") && arguments.contains("--no-cache")
                && !arguments.contains("--baseline")
        )
    }

    @Test func theEfficiencyCoreCountFallsBackToTwo() throws {
        let unknown = FakeRunner { $0.executable == "sysctl" ? CommandResult(status: 1) : fine($0) }
        #expect(try quality(unknown, FakeFileSystem()).efficiencyCores() == 2)
        let garbage = FakeRunner { $0.executable == "sysctl" ? CommandResult(status: 0, output: "many") : fine($0) }
        #expect(try quality(garbage, FakeFileSystem()).efficiencyCores() == 2)
        let zero = FakeRunner { $0.executable == "sysctl" ? CommandResult(status: 0, output: "0\n") : fine($0) }
        #expect(try quality(zero, FakeFileSystem()).efficiencyCores() == 1)
        let six = FakeRunner { $0.executable == "sysctl" ? CommandResult(status: 0, output: "6\n") : fine($0) }
        #expect(try quality(six, FakeFileSystem()).efficiencyCores() == 6)
    }

    @Test func aFullRunFailsOnASurvivorTheBaselineDoesntHold() {
        let files = mutationFiles(baseline: true)
        files.add(reportPath, mutationReport([("/Sources/HubRules/A.swift", "Survived", "fresh")]))
        #expect(throws: QualityError.self) { try quality(FakeRunner(), files).run(.gate(.mutation)) }
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
