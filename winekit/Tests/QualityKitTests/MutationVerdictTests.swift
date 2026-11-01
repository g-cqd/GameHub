import Foundation
import Testing

@testable import QualityKit

@Suite struct MutationVerdictTests {
    let baseline = Data(#"{"undetected": [{"fingerprint": "known", "file": "Sources/A/a.swift", "line": 15}]}"#.utf8)

    @Test func undetectedMutantsAreTheSurvivorsAndTheUncovered() throws {
        let report = mutationReport([
            ("/Sources/A/b.swift", "Survived", "s"), ("/Sources/A/a.swift", "NoCoverage", "n"),
            ("/Sources/A/a.swift", "Killed", "k"),
            ("/Sources/A/a.swift", "Timeout", "t"), ("/Sources/A/a.swift", "CompileError", "c")
        ])
        let undetected = try MutationVerdict.undetected(report: Data(report.utf8))
        #expect(undetected.map(\.fingerprint) == ["n", "s"])  // sorted by file, then line
        #expect(undetected.first?.description == "Sources/A/a.swift:15 RelationalOperatorReplacement < → <=")
    }

    @Test func survivorsTheBaselineHoldsAreAccepted() throws {
        let report = Data(mutationReport([("/Sources/A/a.swift", "Survived", "known")]).utf8)
        #expect(try MutationVerdict.newUndetected(report: report, baseline: baseline).isEmpty)
        #expect(try MutationVerdict.accepted(baseline: baseline) == ["known"])
    }

    @Test func aSurvivorTheBaselineDoesntHoldIsNew() throws {
        let report = Data(
            mutationReport([("/Sources/A/a.swift", "Survived", "known"), ("/Sources/A/a.swift", "Survived", "fresh")])
                .utf8
        )
        #expect(try MutationVerdict.newUndetected(report: report, baseline: baseline).map(\.fingerprint) == ["fresh"])
        #expect(try MutationVerdict.newUndetected(report: report, baseline: nil).count == 2)
    }

    @Test func unreadableFilesAreUnavailable() {
        #expect(throws: QualityError.self) { try MutationVerdict.undetected(report: Data("not json".utf8)) }
        #expect(throws: QualityError.self) { try MutationVerdict.accepted(baseline: Data("{}".utf8)) }
    }

    @Test func aScopedRunFailsOnANewSurvivorAndNamesIt() throws {
        let files = FakeFileSystem([
            "/pkg/Quality/tools.lock": "swift-mutation-testing 1.6.4 \(sha) -",
            "/cache/swift-mutation-testing-1.6.4/swift-mutation-testing": "", "/pkg/Sources/A/a.swift": "",
            "/pkg/.swift-mutation-testing-baseline.json": String(decoding: baseline, as: UTF8.self),
            reportPath: mutationReport([
                ("/Sources/A/a.swift", "Survived", "known"), ("/Sources/A/a.swift", "Survived", "fresh")
            ])
        ])
        let quality = Quality(
            workspace: workspace(),
            runner: FakeRunner(),
            fileSystem: files,
            reporter: FakeReporter(),
            platform: .macOSArm64
        )
        let message =
            "mutation: undetected mutants the baseline doesn't hold: Sources/A/a.swift:15 RelationalOperatorReplacement < → <="
        #expect(throws: QualityError.gateFailed(message)) {
            try quality.mutation(.changed(["Sources/A/a.swift"]))
        }
        files.add(reportPath, mutationReport([("/Sources/A/a.swift", "Survived", "known")]))
        try quality.mutation(.changed(["Sources/A/a.swift"]))
    }

    @Test func aScopedRunWithoutAReportIsUnavailable() {
        let files = FakeFileSystem([
            "/pkg/Quality/tools.lock": "swift-mutation-testing 1.6.4 \(sha) -",
            "/cache/swift-mutation-testing-1.6.4/swift-mutation-testing": ""
        ])
        let quality = Quality(
            workspace: workspace(),
            runner: FakeRunner(),
            fileSystem: files,
            reporter: FakeReporter(),
            platform: .macOSArm64
        )
        #expect(throws: QualityError.unavailable("the mutation run wrote no report at \(reportPath)")) {
            try quality.mutation(.changed(["Sources/A/a.swift"]))
        }
    }

    @Test func aScopedRunWritesItsReportAndPassesNoBaselineToTheTool() throws {
        let files = FakeFileSystem([
            "/pkg/Quality/tools.lock": "swift-mutation-testing 1.6.4 \(sha) -",
            "/cache/swift-mutation-testing-1.6.4/swift-mutation-testing": "",
            "/pkg/.swift-mutation-testing-baseline.json": "{\"undetected\": []}", reportPath: mutationReport()
        ])
        let runner = FakeRunner()
        try Quality(
            workspace: workspace(),
            runner: runner,
            fileSystem: files,
            reporter: FakeReporter(),
            platform: .macOSArm64
        )
        .mutation(.changed(["Sources/A/a.swift"]))
        let arguments = try #require(runner.calls.first).arguments
        #expect(arguments.contains(reportPath) && !arguments.contains("--baseline"))
    }
}
