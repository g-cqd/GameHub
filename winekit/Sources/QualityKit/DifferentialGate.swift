import Foundation

extension Quality {
    /// Wine's hubrules.c against hubrules-swift over the corpus in Differential/; see `Differential`.
    func differential() throws {
        guard let wine = workspace.wineSource,
            fileSystem.fileExists(wine.appendingPathComponent("dlls/ntdll/unix/hubrules.c"))
        else { throw QualityError.unavailable("no Wine checkout with dlls/ntdll/unix/hubrules.c (set WINE_SRC)") }
        let root = workspace.root
        let corpus = root.appendingPathComponent("Differential")
        let work = workspace.scratch.appendingPathComponent("differential")
        for step in [["rm", "-rf", work.path], ["mkdir", "-p", work.appendingPathComponent("rules").path]] {
            try helper(step[0], Array(step.dropFirst()), failure: "could not prepare \(work.path)")
        }
        let inputs = [
            wine.appendingPathComponent("dlls/ntdll/unix/hubrules.c").path,
            corpus.appendingPathComponent("unix_private.h").path,
            corpus.appendingPathComponent("harness.c").path
        ]
        try helper("cp", inputs + [work.path], failure: "could not copy the C sources")
        reporter.step("building Wine's hubrules.c into the C harness")
        try gate(
            "clang", Differential.harnessArguments(work: work.path, wineSource: wine.path),
            failure: "the C harness did not build")
        reporter.step("building hubrules-swift")
        try gate(
            workspace.toolchainTool("swift"),
            ["build"] + workspace.nestedBuildArguments + ["--product", "hubrules-swift"],
            failure: "hubrules-swift did not build")

        let cases = Differential.cases(
            rules: fileSystem.files(under: corpus.appendingPathComponent("rules")).filter { $0.hasSuffix(".txt") }
                .map { corpus.appendingPathComponent("rules/\($0)").path },
            executablesList: String(
                decoding: try fileSystem.contents(corpus.appendingPathComponent("executables")), as: UTF8.self),
            launchers: fileSystem.files(under: corpus.appendingPathComponent("launchers"))
                .map { corpus.appendingPathComponent("launchers/\($0)").path },
            root: root.path, exists: { fileSystem.fileExists(URL(fileURLWithPath: $0)) })
        guard !cases.isEmpty else { throw QualityError.gateFailed("the differential corpus has no case") }

        let rulesDirectory = work.appendingPathComponent("rules")
        let rulesFile = rulesDirectory.appendingPathComponent("hub-rules.txt").path
        let harness = work.appendingPathComponent("harness").path
        let swiftTool = workspace.scratch.appendingPathComponent("debug/hubrules-swift").path
        var different: [DifferentialCase] = []
        for testCase in cases {
            try helper("cp", [testCase.rules, rulesFile], failure: "could not stage \(testCase.rules)")
            let c = try runner.run(
                harness, Differential.harnessCall(testCase, rulesDirectory: rulesDirectory.path), in: root, echo: false)
            let swift = try runner.run(
                swiftTool, Differential.swiftCall(testCase, rulesFile: rulesFile), in: root, echo: false)
            if c.output != swift.output || !c.succeeded || !swift.succeeded {
                different.append(testCase)
                reporter.note(
                    "[DIFF] \(testCase.rules) | \(testCase.executable) | \(testCase.launcher ?? "no launcher")")
            }
        }
        reporter.note("\(cases.count) cases, \(different.count) different")
        guard different.isEmpty else { throw QualityError.gateFailed("hubrules-swift differs from Wine's hubrules.c") }
    }
}
