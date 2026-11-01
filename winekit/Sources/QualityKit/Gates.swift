import Foundation

extension Quality {
    func config() throws {
        let aemi = try aemiDirectory()
        for name in Workspace.configs {
            let canonical = try fileSystem.contents(aemi.appendingPathComponent(name))
            let ours = try? fileSystem.contents(workspace.root.appendingPathComponent(name))
            guard canonical == ours else {
                throw QualityError.gateFailed(
                    "\(name) differs from Aemi's; run  sh \(aemi.path)/Scripts/sync-config.sh ."
                )
            }
        }
        reporter.note("[OK] configuration is Aemi's")
    }

    func format(_ paths: [String], recursive: Bool) throws {
        reporter.step("swift-format lint --strict (\(paths.count) path(s))")
        try gate(
            "swift-format",
            ["lint", "--strict"] + (recursive ? ["-r"] : []) + paths,
            failure: "formatting: run  swift-format format -i on the files above"
        )
    }

    /// SwiftLint over the package, or over `files` only.
    func lint(_ files: [String]?) throws {
        reporter.step("swiftlint --strict")
        try gate(
            "swiftlint",
            ["lint", "--strict", "--quiet", "--no-cache", "--config", ".swiftlint.yml"]
                + (files.map { ["--force-exclude"] + $0 } ?? []),
            failure: "SwiftLint metrics"
        )
    }

    /// The analyzers over the whole corpus (reachability and clones are whole-program), reporting every finding or only
    /// those in the files listed in `onlyFrom`.
    func analyzers(onlyFrom: URL?) throws {
        let aemi = try aemiDirectory()
        let tools = try Lock.parse(
            String(
                decoding: try fileSystem.contents(aemi.appendingPathComponent("Scripts/analyzers.lock")),
                as: UTF8.self
            )
        )
        guard let platform else {
            throw QualityError.unavailable("the analyzers publish macOS arm64 and Linux x86_64 archives only")
        }
        let installer = ToolInstaller(
            runner: runner,
            fileSystem: fileSystem,
            cache: workspace.toolCache,
            platform: platform
        )
        var failed: [String] = []
        for name in ["deadwood", "dolly", "arcleak", "fcheck", "modeler"] {
            guard let tool = tools.first(where: { $0.name == name }) else {
                throw QualityError.unavailable("\(name) is not in Aemi's lock")
            }
            let executable = try installer.executable(for: tool, from: .gcqd)
            reporter.step("\(name) \(tool.version)" + (onlyFrom == nil ? "" : " (reporting the changed files)"))
            let command = name == "modeler" ? "check" : "analyze"
            let corpus = name == "modeler" ? ["Sources"] : Workspace.corpus
            let scope = onlyFrom.map { ["--only-from", $0.path] } ?? []
            let result = try runner.run(
                executable.path,
                [command, "--strict", "--no-cache", "--relative-to", "."] + scope + corpus,
                in: workspace.root,
                echo: true
            )
            if !result.succeeded { failed.append(name) }
        }
        guard failed.isEmpty else { throw QualityError.gateFailed("findings from \(failed.joined(separator: ", "))") }
    }

    func test(release: Bool) throws {
        let scratch = workspace.nestedBuildArguments
        reporter.step("swift test (debug)")
        try gate(workspace.toolchainTool("swift"), ["test"] + scratch, failure: "tests failed in debug")
        guard release else { return }
        reporter.step("swift test -c release")
        try gate(
            workspace.toolchainTool("swift"),
            ["test", "-c", "release", "-Xswiftc", "-enable-testing"] + scratch,
            failure: "tests failed in release"
        )
    }

    func embedded() throws { try wineObjects(into: workspace.scratch.appendingPathComponent("embedded")) }

    /// Mutation testing over the code Wine runs (`Workspace.mutationTargets`), all of it or only `changed`. It runs at
    /// background priority, which puts it on the efficiency cores with throttled I/O, with one worker per efficiency
    /// core, so a game or a build on the performance cores keeps them. A scoped run keeps the tool's result cache. The
    /// gate: a score of at least 90 and no undetected mutant the committed baseline doesn't hold, by fingerprint.
    func mutation(_ scope: MutationScope.Run) throws {
        guard platform == .macOSArm64 else {
            throw QualityError.unavailable("swift-mutation-testing is published for macOS arm64 only")
        }
        let lockText = String(
            decoding: try fileSystem.contents(workspace.root.appendingPathComponent("Quality/tools.lock")),
            as: UTF8.self
        )
        guard let tool = try Lock.parse(lockText).first(where: { $0.name == "swift-mutation-testing" }) else {
            throw QualityError.unavailable("swift-mutation-testing is not in Quality/tools.lock")
        }
        let installer = ToolInstaller(
            runner: runner,
            fileSystem: fileSystem,
            cache: workspace.toolCache,
            platform: .macOSArm64
        )
        let executable = try installer.executable(for: tool, from: .swiftMutationTesting)
        let report = workspace.scratch.appendingPathComponent("mutation-report.json")
        let baseline = workspace.root.appendingPathComponent(".swift-mutation-testing-baseline.json")
        let mutated: [String]
        var arguments = [
            "run", ".", "--sources-path", "Sources", "--operator-tier", "default", "--min-score", "90",
            "--output", report.path, "--concurrency", String(try efficiencyCores())
        ]
        switch scope {
            case .changed(let changed):
                mutated = changed.filter { MutationScope.isMutated($0) }
            case .full(let writeBaseline):
                mutated = Workspace.mutationTargets.flatMap(swiftSources(of:))
                arguments +=
                    ["--no-cache"]
                    + (writeBaseline ? ["--write-baseline", ".swift-mutation-testing-baseline.json"] : [])
        }
        guard !mutated.isEmpty else { return }
        // The command line's excludes replace the configuration's: every other Swift file under Sources is listed.
        let everySource = fileSystem.files(under: workspace.root.appendingPathComponent("Sources"))
            .filter { $0.hasSuffix(".swift") }.map { "Sources/\($0)" }
        arguments += MutationScope.excludeArguments(allSources: everySource, changed: mutated)
        reporter.step("swift-mutation-testing on \(mutated.joined(separator: " ")) (efficiency cores)")
        // taskpolicy -b: background priority, inherited by the builds and test runs it starts. Without WINEKIT_DEV: the
        // dev plugins would lint every mutated build, and a lint failure would read as an unviable mutant.
        try gate(
            "taskpolicy",
            ["-b", "env", "-u", "WINEKIT_DEV", executable.path] + arguments,
            failure: "mutation: the score is under 90"
        )
        guard scope != .full(writeBaseline: true) else { return }
        guard fileSystem.fileExists(report) else {
            throw QualityError.unavailable("the mutation run wrote no report at \(report.path)")
        }
        let new = try MutationVerdict.newUndetected(
            report: try fileSystem.contents(report),
            baseline: fileSystem.fileExists(baseline) ? try fileSystem.contents(baseline) : nil
        )
        guard new.isEmpty else {
            throw QualityError.gateFailed(
                "mutation: undetected mutants the baseline doesn't hold: \(new.map(\.description).joined(separator: "; "))"
            )
        }
    }

    /// The efficiency cores (`hw.perflevel1.logicalcpu`), or 2 when the machine doesn't say.
    func efficiencyCores() throws -> Int {
        let answer = try runner.run("sysctl", ["-n", "hw.perflevel1.logicalcpu"], in: workspace.root, echo: false)
        return answer.succeeded ? Int(answer.output.trimmed).map { max(1, $0) } ?? 2 : 2
    }
}
