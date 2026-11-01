import Foundation

extension Quality {
    /// The C implementation as it was against Wine's hubrules.c with WineKit; see `Differential`.
    func differential() throws {
        guard let wine = workspace.wineSource,
            fileSystem.fileExists(wine.appendingPathComponent("dlls/ntdll/unix/hubrules.c"))
        else { throw QualityError.unavailable("no Wine checkout with dlls/ntdll/unix/hubrules.c (set WINE_SRC)") }
        let corpus = workspace.root.appendingPathComponent("Differential")
        let work = workspace.scratch.appendingPathComponent("differential")
        for step in [["rm", "-rf", work.path], ["mkdir", "-p", work.appendingPathComponent("rules").path]] {
            try helper(step[0], Array(step.dropFirst()), failure: "could not prepare \(work.path)")
        }
        let objects = work.appendingPathComponent("winekit")
        try wineObjects(into: objects)
        let reference = try harness(
            "reference",
            source: corpus.appendingPathComponent("reference/hubrules.c"),
            work: work,
            extra: []
        )
        let candidate = try harness(
            "wine",
            source: wine.appendingPathComponent("dlls/ntdll/unix/hubrules.c"),
            work: work,
            extra: ["-I\(objects.path)", objects.appendingPathComponent("libwinekit.a").path]
        )

        let cases = Differential.cases(
            rules: fileSystem.files(under: corpus.appendingPathComponent("rules")).filter { $0.hasSuffix(".txt") }
                .map { corpus.appendingPathComponent("rules/\($0)").path },
            executablesList: String(
                decoding: try fileSystem.contents(corpus.appendingPathComponent("executables")),
                as: UTF8.self
            ),
            launchers: fileSystem.files(under: corpus.appendingPathComponent("launchers"))
                .map { corpus.appendingPathComponent("launchers/\($0)").path },
            root: workspace.root.path,
            exists: { fileSystem.fileExists(URL(fileURLWithPath: $0)) }
        )
        guard !cases.isEmpty else { throw QualityError.gateFailed("the differential corpus has no case") }

        let rulesDirectory = work.appendingPathComponent("rules").path
        var different: [DifferentialCase] = []
        for testCase in cases {
            try helper(
                "cp",
                [testCase.rules, rulesDirectory + "/hub-rules.txt"],
                failure: "could not stage \(testCase.rules)"
            )
            let call = Differential.harnessCall(testCase, rulesDirectory: rulesDirectory)
            let before = try runner.run(reference, call, in: workspace.root, echo: false)
            let after = try runner.run(candidate, call, in: workspace.root, echo: false)
            if before != after || !before.succeeded {
                different.append(testCase)
                reporter.note(
                    "[DIFF] \(testCase.rules) | \(testCase.executable) | \(testCase.launcher ?? "no launcher")"
                )
            }
        }
        reporter.note("\(cases.count) cases, \(different.count) different")
        guard different.isEmpty else {
            throw QualityError.gateFailed("Wine's hubrules.c with WineKit differs from the reference C")
        }
    }

    /// Builds the harness around `source` in work/<name> and returns its path.
    private func harness(_ name: String, source: URL, work: URL, extra: [String]) throws -> String {
        let directory = work.appendingPathComponent(name)
        let corpus = workspace.root.appendingPathComponent("Differential")
        try helper("mkdir", ["-p", directory.path], failure: "could not create \(directory.path)")
        let inputs = [
            source.path, corpus.appendingPathComponent("unix_private.h").path,
            corpus.appendingPathComponent("harness.c").path
        ]
        try helper("cp", inputs + [directory.path], failure: "could not copy the \(name) sources")
        reporter.step("building the \(name) harness")
        try gate(
            "clang",
            Differential.harnessArguments(
                work: directory.path,
                wineSource: workspace.wineSource?.path ?? "",
                extra: extra
            ),
            failure: "the \(name) harness did not build"
        )
        return directory.appendingPathComponent("harness").path
    }
}
