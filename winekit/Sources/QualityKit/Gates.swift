import Foundation

extension Quality {
    func config() throws {
        let aemi = try aemiDirectory()
        for name in Workspace.configs {
            let canonical = try fileSystem.contents(aemi.appendingPathComponent(name))
            let ours = try? fileSystem.contents(workspace.root.appendingPathComponent(name))
            guard canonical == ours else {
                throw QualityError.gateFailed(
                    "\(name) differs from Aemi's; run  sh \(aemi.path)/scripts/sync-config.sh .")
            }
        }
        reporter.note("[OK] configuration is Aemi's")
    }

    func format(_ paths: [String], recursive: Bool) throws {
        reporter.step("swift-format lint --strict (\(paths.count) path(s))")
        try gate(
            "swift-format", ["lint", "--strict"] + (recursive ? ["-r"] : []) + paths,
            failure: "formatting: run  swift-format format -i on the files above")
    }

    /// SwiftLint over the package, or over `files` only.
    func lint(_ files: [String]?) throws {
        reporter.step("swiftlint --strict")
        try gate(
            "swiftlint",
            ["lint", "--strict", "--quiet", "--no-cache", "--config", ".swiftlint.yml"]
                + (files.map { ["--force-exclude"] + $0 } ?? []),
            failure: "SwiftLint metrics")
    }

    /// The analyzers over the whole corpus (reachability and clones are whole-program), reporting every finding or only
    /// those in the files listed in `onlyFrom`.
    func analyzers(onlyFrom: URL?) throws {
        let aemi = try aemiDirectory()
        let tools = try Lock.parse(
            String(
                decoding: try fileSystem.contents(aemi.appendingPathComponent("scripts/analyzers.lock")), as: UTF8.self)
        )
        guard let platform else {
            throw QualityError.unavailable("the analyzers publish macOS arm64 and Linux x86_64 archives only")
        }
        let installer = ToolInstaller(
            runner: runner, fileSystem: fileSystem, cache: workspace.toolCache, platform: platform)
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
                executable.path, [command, "--strict", "--no-cache", "--relative-to", "."] + scope + corpus,
                in: workspace.root, echo: true)
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
            workspace.toolchainTool("swift"), ["test", "-c", "release", "-Xswiftc", "-enable-testing"] + scratch,
            failure: "tests failed in release")
    }

    func embedded() throws {
        let out = workspace.scratch.appendingPathComponent("embedded")
        try helper("mkdir", ["-p", out.path], failure: "could not create \(out.path)")
        for module in Workspace.embeddedTargets {
            let sources = swiftSources(of: module)
            let object = out.appendingPathComponent("\(module).o").path
            reporter.step("Embedded Swift: \(module) (\(EmbeddedCheck.target))")
            try gate(
                workspace.toolchainTool("swiftc"),
                EmbeddedCheck.compileArguments(module: module, sources: sources, object: object),
                failure: "\(module) does not compile as Embedded Swift")
            let symbols = try runner.run("nm", [object], in: workspace.root, echo: false)
            let outside = EmbeddedCheck.disallowed(nmOutput: symbols.output)
            guard outside.isEmpty else {
                throw QualityError.gateFailed("\(module) needs \(outside.joined(separator: ", ")), outside libc")
            }
        }
    }

    /// Mutation testing over the library sources, or only over `changed`. A scoped run keeps the tool's result cache, so a
    /// push reuses what the commit already ran. The gate: no survivor the committed baseline doesn't hold, score ≥ 90.
    func mutation(changed: [String]?, writeBaseline: Bool = false) throws {
        guard platform == .macOSArm64 else {
            throw QualityError.unavailable("swift-mutation-testing is published for macOS arm64 only")
        }
        let lockText = String(
            decoding: try fileSystem.contents(workspace.root.appendingPathComponent("Quality/tools.lock")),
            as: UTF8.self)
        guard let tool = try Lock.parse(lockText).first(where: { $0.name == "swift-mutation-testing" }) else {
            throw QualityError.unavailable("swift-mutation-testing is not in Quality/tools.lock")
        }
        let installer = ToolInstaller(
            runner: runner, fileSystem: fileSystem, cache: workspace.toolCache, platform: .macOSArm64)
        let executable = try installer.executable(for: tool, from: .swiftMutationTesting)
        let all = libraryTargets.flatMap(swiftSources(of:))
        var arguments = [
            "run", ".", "--sources-path", "Sources", "--operator-tier", "experimental", "--min-score", "90"
        ]
        if let changed {
            arguments += MutationScope.excludeArguments(allSources: all, changed: changed)
            reporter.step("swift-mutation-testing on \(changed.joined(separator: " "))")
        } else {
            arguments += ["--no-cache"]
            reporter.step("swift-mutation-testing on every library source")
        }
        if writeBaseline {
            arguments += ["--write-baseline", ".swift-mutation-testing-baseline.json"]
        } else if fileSystem.fileExists(workspace.root.appendingPathComponent(".swift-mutation-testing-baseline.json"))
        {
            arguments += ["--baseline", ".swift-mutation-testing-baseline.json", "--max-new-survivors", "0"]
        }
        // Without WINEKIT_DEV: the dev plugins would lint every mutated build, and a lint failure would read as an
        // unviable mutant rather than a result.
        try gate(
            "env", ["-u", "WINEKIT_DEV", executable.path] + arguments,
            failure: "mutation: a mutant survived that the baseline does not hold, or the score is under 90")
    }
}
