import Foundation

extension Quality {
    /// Builds what Wine links into `output`: libwinekit.a and winekit.h, its C interface. The archive holds Aemi's C
    /// kernels (CAemiCPU's feature set and CAemiKernels, with the sources and strict flags Aemi's Scripts/lib/c-targets.sh
    /// names), Aemi's Embedded Swift modules (`EmbeddedCheck.aemiModules`) and the libraries Wine uses
    /// (`Workspace.embeddedTargets`), all for Wine's Unix side. Together they may leave only libc symbols undefined, and
    /// they must define every symbol the header declares. The `embedded` gate runs this into the scratch directory.
    func wineObjects(into output: URL) throws {
        let aemi = try aemiDirectory()
        let aemiOutput = output.appendingPathComponent("aemi")
        try helper("mkdir", ["-p", aemiOutput.path], failure: "could not create \(aemiOutput.path)")
        var objects = try aemiCObjects(aemi: aemi, into: aemiOutput)
        let includeKernels = ["-I", aemi.appendingPathComponent("Sources/CAemiKernels/include").path]
        for module in EmbeddedCheck.aemiModules {
            let sources = fileSystem.files(under: aemi.appendingPathComponent("Sources/\(module)"))
                .filter { $0.hasSuffix(".swift") }.map { aemi.appendingPathComponent("Sources/\(module)/\($0)").path }
            let interface = aemiOutput.appendingPathComponent("\(module).swiftmodule").path
            objects.append(
                try embeddedSwift(
                    module: module,
                    sources: sources,
                    object: aemiOutput.appendingPathComponent("\(module).o").path,
                    options: includeKernels + ["-I", aemiOutput.path, "-emit-module", "-emit-module-path", interface]
                )
            )
        }
        for module in Workspace.embeddedTargets {
            objects.append(
                try embeddedSwift(
                    module: module,
                    sources: swiftSources(of: module),
                    object: output.appendingPathComponent("\(module).o").path,
                    options: includeKernels + ["-I", aemiOutput.path]
                )
            )
        }
        var nmOutput = ""
        for object in objects { nmOutput += try runner.run("nm", [object], in: workspace.root, echo: false).output }
        let outside = EmbeddedCheck.disallowed(nmOutput: nmOutput)
        guard outside.isEmpty else {
            throw QualityError.gateFailed("libwinekit.a needs \(outside.joined(separator: ", ")), outside libc")
        }
        let missing = EmbeddedCheck.missingExports(nmOutput: nmOutput)
        guard missing.isEmpty else {
            throw QualityError.gateFailed(
                "winekit.h declares \(missing.joined(separator: ", ")), which no library defines"
            )
        }
        let library = output.appendingPathComponent("libwinekit.a").path
        try helper("rm", ["-f", library], failure: "could not replace \(library)")
        try helper("ar", ["rcs", library] + objects, failure: "could not archive \(library)")
        try helper(
            "cp",
            [workspace.root.appendingPathComponent("C/winekit.h").path, output.path],
            failure: "could not copy winekit.h"
        )
        reporter.note("[OK] \(library) and winekit.h")
    }

    /// Compiles one module as Embedded Swift for Wine's Unix side and returns its object.
    private func embeddedSwift(module: String, sources: [String], object: String, options: [String]) throws -> String {
        reporter.step("Embedded Swift: \(module) (\(EmbeddedCheck.target))")
        try gate(
            workspace.toolchainTool("swiftc"),
            EmbeddedCheck.compileArguments(module: module, sources: sources, object: object, options: options),
            failure: "\(module) does not compile as Embedded Swift"
        )
        return object
    }

    /// Compiles the C an Embedded consumer of AemiKernels needs, as Aemi's c-targets.sh describes it, into `output`.
    private func aemiCObjects(aemi: URL, into output: URL) throws -> [String] {
        let script = try runner.run(
            "sh",
            ["-c", EmbeddedCheck.cTargetsScript, "sh", aemi.path],
            in: workspace.root,
            echo: false
        )
        guard script.succeeded, let targets = EmbeddedCheck.CTargets(scriptOutput: script.output) else {
            throw QualityError.unavailable("could not read Aemi's Scripts/lib/c-targets.sh: \(script.errors.trimmed)")
        }
        reporter.step("C: Aemi's kernels (\(EmbeddedCheck.target))")
        return try targets.sources.map { source in
            let name = (source as NSString).lastPathComponent.replacingOccurrences(of: ".c", with: ".o")
            let object = output.appendingPathComponent(name).path
            try gate(
                "clang",
                EmbeddedCheck.cCompileArguments(
                    source: source,
                    object: object,
                    flags: targets.flags,
                    includes: targets.includes
                ),
                failure: "\(name) does not compile"
            )
            return object
        }
    }
}
