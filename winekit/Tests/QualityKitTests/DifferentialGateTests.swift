import Foundation
import Testing

@testable import QualityKit

@Suite struct DifferentialGateTests {
    func corpus() -> FakeFileSystem {
        FakeFileSystem([
            "/wine/dlls/ntdll/unix/hubrules.c": "", "/pkg/Differential/unix_private.h": "",
            "/pkg/Differential/harness.c": "",
            "/pkg/Differential/rules/a.txt": "", "/pkg/Differential/rules/notes.md": "",
            "/pkg/Differential/executables": "$ROOT/game.exe\n/absent.exe\n", "/pkg/game.exe": "",
            "/pkg/Differential/launchers/v3": ""
        ])
    }

    /// Both sides print `c` and `swift` for every case.
    func runner(c: String = "same", swift: String = "same") -> FakeRunner {
        FakeRunner { call in
            if call.executable.hasSuffix("/harness") { return CommandResult(status: 0, output: c) }
            if call.executable.hasSuffix("/hubrules-swift") { return CommandResult(status: 0, output: swift) }
            return CommandResult(status: 0)
        }
    }

    func quality(_ runner: FakeRunner, _ files: FakeFileSystem, wine: URL? = wineRoot) -> Quality {
        Quality(
            workspace: workspace(wine: wine),
            runner: runner,
            fileSystem: files,
            reporter: FakeReporter(),
            platform: .macOSArm64
        )
    }

    @Test func identicalOutputsPassEveryCase() throws {
        let runner = runner()
        try quality(runner, corpus()).run(.gate(.differential))
        #expect(runner.calls(to: "/harness").count == 2)  // one rules file × one existing executable × (none, v3)
        #expect(
            runner.calls(to: "/hubrules-swift").map(\.arguments) == [
                ["/pkg/.build/quality/differential/rules/hub-rules.txt", "/pkg/game.exe"],
                [
                    "/pkg/.build/quality/differential/rules/hub-rules.txt", "/pkg/game.exe",
                    "/pkg/Differential/launchers/v3"
                ]
            ]
        )
        #expect(runner.calls(to: "clang").first?.arguments.contains("-I/wine/include") == true)
    }

    @Test func aDifferenceFailsTheGate() {
        #expect(throws: QualityError.gateFailed("hubrules-swift differs from Wine's hubrules.c")) {
            try quality(runner(c: "v=3\n", swift: "v=3"), corpus()).run(.gate(.differential))
        }
    }

    @Test func aSideThatFailsIsADifference() {
        let crashing = FakeRunner {
            $0.executable.hasSuffix("/hubrules-swift") ? CommandResult(status: 1) : CommandResult(status: 0)
        }
        #expect(throws: QualityError.gateFailed("hubrules-swift differs from Wine's hubrules.c")) {
            try quality(crashing, corpus()).run(.gate(.differential))
        }
    }

    @Test func itNeedsAWineCheckout() {
        let message = "no Wine checkout with dlls/ntdll/unix/hubrules.c (set WINE_SRC)"
        #expect(throws: QualityError.unavailable(message)) {
            try quality(runner(), corpus(), wine: nil).run(.gate(.differential))
        }
        #expect(throws: QualityError.unavailable(message)) {
            try quality(runner(), FakeFileSystem(), wine: wineRoot).run(.gate(.differential))
        }
    }

    @Test func anEmptyCorpusFails() {
        let files = corpus()
        files.add("/pkg/Differential/executables", "/absent.exe\n")
        #expect(throws: QualityError.gateFailed("the differential corpus has no case")) {
            try quality(runner(), files).run(.gate(.differential))
        }
    }

    @Test func aHelperThatFailsMakesTheGateUnavailable() {
        let readOnly = FakeRunner {
            $0.executable == "mkdir" ? CommandResult(status: 1, errors: "read-only\n") : CommandResult(status: 0)
        }
        #expect(throws: QualityError.unavailable("could not prepare /pkg/.build/quality/differential: read-only")) {
            try quality(readOnly, corpus()).run(.gate(.differential))
        }
    }

    @Test func aHarnessThatDoesNotBuildFails() {
        let noClang = FakeRunner { $0.executable == "clang" ? CommandResult(status: 1) : CommandResult(status: 0) }
        #expect(throws: QualityError.gateFailed("the C harness did not build")) {
            try quality(noClang, corpus()).run(.gate(.differential))
        }
    }
}
