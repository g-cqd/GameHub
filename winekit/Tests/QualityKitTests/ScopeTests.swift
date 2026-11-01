import Testing

@testable import QualityKit

@Suite struct ScopeTests {
    let changes = ChangeSet(
        files: [
            "Sources/HubRules/PEFacts.swift", "Sources/hubrules-swift/main.swift", "Sources/QualityKit/Lock.swift",
            "Tests/HubRulesTests/X.swift", "Package.swift", "README.md", "Differential/rules/edges.txt"
        ],
        libraryTargets: ["HubRules", "QualityKit"]
    )

    @Test func sortsTheFilesForEachGate() {
        #expect(changes.swiftFiles.count == 5)
        #expect(changes.librarySources == ["Sources/HubRules/PEFacts.swift", "Sources/QualityKit/Lock.swift"])
        #expect(changes.manifestChanged)
        #expect(changes.touchesDifferential)
        #expect(!changes.isEmpty)
    }

    @Test func aLibraryNameIsMatchedAsAWholeDirectory() {
        let similar = ChangeSet(files: ["Sources/HubRulesExtra/A.swift"], libraryTargets: ["HubRules"])
        #expect(similar.librarySources.isEmpty)
    }

    @Test func theDifferentialTestFollowsTheEngineTheToolAndTheCorpus() {
        for file in ["Sources/HubRules/A.swift", "Sources/hubrules-swift/main.swift", "Differential/executables"] {
            #expect(ChangeSet(files: [file], libraryTargets: []).touchesDifferential)
        }
        let unrelated = ChangeSet(files: ["Sources/QualityKit/Lock.swift", "README.md"], libraryTargets: ["QualityKit"])
        #expect(!unrelated.touchesDifferential)
        #expect(!unrelated.manifestChanged)
        #expect(ChangeSet(files: [], libraryTargets: []).isEmpty)
    }

    @Test func gitListsStagedFilesForACommitAndTheBranchForAPush() {
        #expect(
            ChangeSet.gitArguments(for: .preCommit, base: "ignored")
                == ["diff", "--cached", "--relative", "--name-only", "--diff-filter=ACMR", "--", "."]
        )
        #expect(
            ChangeSet.gitArguments(for: .prePush, base: "origin/topic")
                == ["diff", "--relative", "--name-only", "--diff-filter=ACMR", "origin/topic...HEAD", "--", "."]
        )
        #expect(ChangeSet.gitArguments(for: .prePush, base: nil).contains("origin/main...HEAD"))
    }

    @Test func gitOutputBecomesPaths() {
        #expect(ChangeSet.paths(fromGitOutput: "a.swift\n\n  b/c.swift \n") == ["a.swift", "b/c.swift"])
        #expect(ChangeSet.paths(fromGitOutput: "").isEmpty)
    }

    @Test func undefinedSymbolsComeFromNMOutput() {
        let output =
            "0000000000000000 T _swift_count\n                 U _free\n                 U _objc_msgSend\nbogus line here\n"
            + "0000000000000010 _two_fields\n"
        #expect(EmbeddedCheck.undefinedSymbols(nmOutput: output) == ["_free", "_objc_msgSend"])
        #expect(EmbeddedCheck.disallowed(nmOutput: output) == ["_objc_msgSend"])
        #expect(EmbeddedCheck.disallowed(nmOutput: "                 U _posix_memalign\n").isEmpty)
    }

    @Test func embeddedCompilationTargetsWinesUnixSide() {
        let arguments = EmbeddedCheck.compileArguments(module: "M", sources: ["a.swift", "b.swift"], object: "o.o")
        #expect(arguments.starts(with: ["-target", "x86_64-apple-macos15", "-enable-experimental-feature", "Embedded"]))
        #expect(arguments.suffix(5) == ["a.swift", "b.swift", "-emit-object", "-o", "o.o"])
        #expect(arguments.contains("-strict-memory-safety"))
    }

    @Test func mutationExcludesEveryUnchangedSource() {
        let arguments = MutationScope.excludeArguments(
            allSources: ["Sources/A/z.swift", "Sources/A/a.swift", "Sources/B/b.swift"],
            changed: ["Sources/A/a.swift"]
        )
        #expect(arguments == ["--exclude", "/Sources/A/z.swift", "--exclude", "/Sources/B/b.swift"].sortedPairs())
        #expect(MutationScope.excludeArguments(allSources: ["x"], changed: ["x"]).isEmpty)
    }

    @Test func differentialCasesCrossRulesExecutablesAndLaunchers() {
        let cases = Differential.cases(
            rules: ["/r/b.txt", "/r/a.txt"],
            executablesList: "# comment\n\n$ROOT/x.exe\n/missing.exe\n /y.exe \n",
            launchers: ["/l/2", "/l/1"],
            root: "/pkg",
            exists: { $0 != "/missing.exe" }
        )
        #expect(cases.count == 2 * 2 * 3)
        #expect(cases.first == DifferentialCase(rules: "/r/a.txt", executable: "/pkg/x.exe", launcher: nil))
        #expect(cases[1].launcher == "/l/1")
        #expect(cases.last == DifferentialCase(rules: "/r/b.txt", executable: "/y.exe", launcher: "/l/2"))
    }

    @Test func theTwoSidesAreCalledWithTheSameCase() {
        let testCase = DifferentialCase(rules: "/r/a.txt", executable: "/e.exe", launcher: "/l/1")
        #expect(Differential.harnessCall(testCase, rulesDirectory: "/w/rules") == ["/w/rules", "/e.exe", "/l/1"])
        #expect(
            Differential.swiftCall(testCase, rulesFile: "/w/rules/hub-rules.txt") == [
                "/w/rules/hub-rules.txt", "/e.exe", "/l/1"
            ]
        )
        let bare = DifferentialCase(rules: "/r/a.txt", executable: "/e.exe", launcher: nil)
        #expect(Differential.harnessCall(bare, rulesDirectory: "/w") == ["/w", "/e.exe"])
        #expect(Differential.swiftCall(bare, rulesFile: "/w/h") == ["/w/h", "/e.exe"])
        let harness = Differential.harnessArguments(work: "/w", wineSource: "/wine")
        #expect(harness.contains("-I/wine/include") && harness.contains("x86_64") && harness.last == "/w/harness.c")
    }
}

extension [String] {
    /// The ["--exclude", path] pairs ordered by path.
    func sortedPairs() -> [String] {
        stride(from: 0, to: count, by: 2).map { [self[$0], self[$0 + 1]] }.sorted { $0[1] < $1[1] }.flatMap { $0 }
    }
}
