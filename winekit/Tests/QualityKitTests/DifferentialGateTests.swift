import Foundation
import Testing

@testable import QualityKit

@Suite struct DifferentialGateTests {
    func corpus() -> FakeFileSystem {
        FakeFileSystem([
            "/wine/dlls/ntdll/unix/hubrules.c": "", "/pkg/Differential/unix_private.h": "",
            "/pkg/Differential/harness.c": "",
            "/pkg/Differential/reference/hubrules.c": "", "/pkg/Differential/rules/a.txt": "",
            "/pkg/Differential/rules/notes.md": "", "/pkg/Differential/executables": "$ROOT/game.exe\n/absent.exe\n",
            "/pkg/game.exe": "", "/pkg/Differential/launchers/v3": "", "/pkg/Sources/HubRules/A.swift": ""
        ])
    }

    /// The reference harness answers `reference`, Wine's answers `wine`.
    func runner(
        reference: CommandResult = CommandResult(status: 0, output: "same", errors: "note"),
        wine: CommandResult = CommandResult(status: 0, output: "same", errors: "note")
    ) -> FakeRunner {
        FakeRunner { call in
            if call.executable.hasSuffix("/reference/harness") { return reference }
            if call.executable.hasSuffix("/wine/harness") { return wine }
            return fine(call)
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

    @Test func bothHarnessesRunEveryCaseWithTheSameArguments() throws {
        let runner = runner()
        try quality(runner, corpus()).run(.gate(.differential))
        let reference = runner.calls(to: "/reference/harness").map(\.arguments)
        #expect(reference == runner.calls(to: "/wine/harness").map(\.arguments))
        // one rules file × one existing executable × (no launcher, v3)
        #expect(
            reference == [
                ["/pkg/.build/quality/differential/rules", "/pkg/game.exe"],
                ["/pkg/.build/quality/differential/rules", "/pkg/game.exe", "/pkg/Differential/launchers/v3"]
            ]
        )
    }

    @Test func wineIsBuiltWithWineKitAndTheReferenceWithout() throws {
        let runner = runner()
        try quality(runner, corpus()).run(.gate(.differential))
        // the harnesses; the other clang calls build Aemi's C kernels into libwinekit.a
        let builds = runner.calls(to: "clang").map(\.arguments).filter { !$0.contains("-c") }
        #expect(builds.count == 2)
        let objects = "/pkg/.build/quality/differential/winekit"
        #expect(
            builds[0].contains("/pkg/.build/quality/differential/reference/harness.c")
                && !builds[0].contains("-I\(objects)")
        )
        #expect(builds[1].suffix(2) == ["-I\(objects)", "\(objects)/libwinekit.a"])
        #expect(runner.calls(to: "ar").first?.arguments.dropFirst().first == "\(objects)/libwinekit.a")
        let copies = runner.calls(to: "cp").map(\.arguments)
        #expect(copies.contains { $0.first == "/pkg/Differential/reference/hubrules.c" })
        #expect(copies.contains { $0.first == "/wine/dlls/ntdll/unix/hubrules.c" })
    }

    @Test func aDifferenceOnEitherStreamFailsTheGate() {
        let message = "Wine's hubrules.c with WineKit differs from the reference C"
        let stdout = runner(wine: CommandResult(status: 0, output: "other", errors: "note"))
        #expect(throws: QualityError.gateFailed(message)) { try quality(stdout, corpus()).run(.gate(.differential)) }
        let stderr = runner(wine: CommandResult(status: 0, output: "same", errors: "warning"))
        #expect(throws: QualityError.gateFailed(message)) { try quality(stderr, corpus()).run(.gate(.differential)) }
    }

    @Test func aReferenceThatFailsIsADifferenceEvenWhenBothFailAlike() {
        let failing = CommandResult(status: 1)
        #expect(throws: QualityError.gateFailed("Wine's hubrules.c with WineKit differs from the reference C")) {
            try quality(runner(reference: failing, wine: failing), corpus()).run(.gate(.differential))
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
            $0.executable == "mkdir" ? CommandResult(status: 1, errors: "read-only\n") : fine($0)
        }
        #expect(throws: QualityError.unavailable("could not prepare /pkg/.build/quality/differential: read-only")) {
            try quality(readOnly, corpus()).run(.gate(.differential))
        }
    }

    @Test func aHarnessThatDoesNotBuildFails() {
        let noClang = FakeRunner {
            $0.executable == "clang" && $0.arguments.contains { $0.hasSuffix("wine/harness.c") }
                ? CommandResult(status: 1) : fine($0)
        }
        #expect(throws: QualityError.gateFailed("the wine harness did not build")) {
            try quality(noClang, corpus()).run(.gate(.differential))
        }
    }
}
