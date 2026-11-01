import Foundation
import Testing

@testable import QualityKit

/// What each gate tells the person running it, and which commands print to the terminal.
@Suite struct ReportingTests {
    func run(
        _ request: Request,
        files: FakeFileSystem = FakeFileSystem(),
        runner: FakeRunner = FakeRunner()
    ) throws -> [String] {
        let reporter = FakeReporter()
        try Quality(
            workspace: workspace(),
            runner: runner,
            fileSystem: files,
            reporter: reporter,
            platform: .macOSArm64
        )
        .run(request)
        return reporter.lines
    }

    @Test func staticGatesNameTheirTool() throws {
        #expect(try run(.gate(.format)) == ["==> swift-format lint --strict (4 path(s))"])
        #expect(try run(.gate(.lint)) == ["==> swiftlint --strict"])
        #expect(try run(.gate(.tags)) == ["==> check-tags.sh all"])
        let configs = FakeFileSystem([
            "/aemi/.swift-format": "", "/aemi/.swiftlint.yml": "", "/pkg/.swift-format": "", "/pkg/.swiftlint.yml": ""
        ])
        #expect(try run(.gate(.config), files: configs) == ["[OK] configuration is Aemi's"])
    }

    @Test func analyzersSayWhetherTheyReportEverythingOrTheChange() throws {
        let files = FakeFileSystem()
        installedAnalyzers(files)
        #expect(try run(.gate(.analyzers), files: files).first == "==> deadwood 1.0.0")
        let reporter = FakeReporter()
        try Quality(
            workspace: workspace(),
            runner: FakeRunner(),
            fileSystem: files,
            reporter: reporter,
            platform: .macOSArm64
        )
        .analyzers(onlyFrom: URL(fileURLWithPath: "/list"))
        #expect(reporter.lines.last == "==> modeler 1.0.0 (reporting the changed files)")
    }

    @Test func testsAndEmbeddedNameTheirStage() throws {
        #expect(try run(.gate(.test)) == ["==> swift test (debug)", "==> swift test -c release"])
        #expect(
            try run(.gate(.embedded)) == [
                "==> Embedded Swift: HubRules (x86_64-apple-macos15)",
                "[OK] /pkg/.build/quality/embedded/libwinekit.a and winekit.h"
            ]
        )
    }

    @Test func mutationSaysWhatItMutates() throws {
        let files = FakeFileSystem([
            "/pkg/Quality/tools.lock": "swift-mutation-testing 1.6.4 \(sha) -",
            "/cache/swift-mutation-testing-1.6.4/swift-mutation-testing": "", "/pkg/Sources/HubRules/A.swift": "",
            reportPath: mutationReport()
        ])
        #expect(
            try run(.gate(.mutation), files: files) == [
                "==> swift-mutation-testing on Sources/HubRules/A.swift (efficiency cores)"
            ]
        )
        let reporter = FakeReporter()
        try Quality(
            workspace: workspace(),
            runner: FakeRunner(),
            fileSystem: files,
            reporter: reporter,
            platform: .macOSArm64
        )
        .mutation(.changed(["Sources/HubRules/A.swift", "Sources/HubRules/B.swift"]))
        #expect(
            reporter.lines == [
                "==> swift-mutation-testing on Sources/HubRules/A.swift Sources/HubRules/B.swift (efficiency cores)"
            ]
        )
    }

    @Test func anUnchangedPackageSaysSo() throws {
        let gitSaysNothing = FakeRunner { _ in CommandResult(status: 0, output: "") }
        #expect(try run(.changed(.preCommit), runner: gitSaysNothing) == ["[OK] pre-commit: no change to the package"])
    }

    @Test func theDifferentialTestCountsAndNamesItsDifferences() throws {
        let files = FakeFileSystem([
            "/wine/dlls/ntdll/unix/hubrules.c": "", "/pkg/Differential/rules/a.txt": "",
            "/pkg/Differential/executables": "/pkg/g.exe",
            "/pkg/g.exe": "", "/pkg/Sources/HubRules/A.swift": ""
        ])
        #expect(
            try run(.gate(.differential), files: files) == [
                "==> Embedded Swift: HubRules (x86_64-apple-macos15)",
                "[OK] /pkg/.build/quality/differential/winekit/libwinekit.a and winekit.h",
                "==> building the reference harness", "==> building the wine harness", "1 cases, 0 different"
            ]
        )
        let differing = FakeRunner {
            $0.executable.hasSuffix("/wine/harness") ? CommandResult(status: 0, output: "x") : fine($0)
        }
        let reporter = FakeReporter()
        #expect(throws: QualityError.self) {
            try Quality(
                workspace: workspace(),
                runner: differing,
                fileSystem: files,
                reporter: reporter,
                platform: .macOSArm64
            )
            .run(.gate(.differential))
        }
        #expect(
            reporter.lines.suffix(2) == [
                "[DIFF] /pkg/Differential/rules/a.txt | /pkg/g.exe | no launcher", "1 cases, 1 different"
            ]
        )
    }

    @Test func onlyTheGateToolsPrintAndEveryHelperIsCaptured() throws {
        let files = FakeFileSystem([
            "/pkg/Sources/HubRules/A.swift": "", "/wine/dlls/ntdll/unix/hubrules.c": "",
            "/pkg/Differential/rules/a.txt": "",
            "/pkg/Differential/executables": "/pkg/Sources/HubRules/A.swift",
            "/pkg/Quality/tools.lock": "swift-mutation-testing 1.6.4 \(sha) -",
            "/cache/.download-swift-mutation-testing-1.6.4/swift-mutation-testing": "", reportPath: mutationReport()
        ])
        installedAnalyzers(files)
        let runner = FakeRunner { call in
            switch call.executable {
                case "git": CommandResult(status: 0, output: "Sources/HubRules/A.swift\n")
                case "shasum": CommandResult(status: 0, output: "\(sha)  x\n")
                case let path where path.hasSuffix("/swift-mutation-testing") && call.arguments == ["--version"]:
                    CommandResult(status: 0, output: "1.6.4\n")
                default: fine(call)
            }
        }
        _ = try run(.changed(.prePush), files: files, runner: runner)
        let printing: Set<String> = [
            "sh", "swift-format", "swiftlint", "deadwood", "dolly", "arcleak", "fcheck", "modeler", "swift", "swiftc",
            "clang", "taskpolicy"
        ]
        for call in runner.calls {
            let name = URL(fileURLWithPath: call.executable).lastPathComponent
            #expect(call.echo == printing.contains(name), "\(name) \(call.arguments)")
        }
    }
}
