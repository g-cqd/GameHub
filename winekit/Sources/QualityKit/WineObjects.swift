import Foundation

extension Quality {
    /// Builds what Wine links into `output`: libwinekit.a, the Embedded Swift objects of the libraries Wine uses, and
    /// winekit.h, their C interface. Each object may leave only libc symbols undefined, and together they must define
    /// every symbol the header declares. The `embedded` gate runs this into the scratch directory.
    func wineObjects(into output: URL) throws {
        try helper("mkdir", ["-p", output.path], failure: "could not create \(output.path)")
        var objects: [String] = []
        var nmOutput = ""
        for module in Workspace.embeddedTargets {
            let object = output.appendingPathComponent("\(module).o").path
            reporter.step("Embedded Swift: \(module) (\(EmbeddedCheck.target))")
            try gate(
                workspace.toolchainTool("swiftc"),
                EmbeddedCheck.compileArguments(module: module, sources: swiftSources(of: module), object: object),
                failure: "\(module) does not compile as Embedded Swift"
            )
            let symbols = try runner.run("nm", [object], in: workspace.root, echo: false)
            let outside = EmbeddedCheck.disallowed(nmOutput: symbols.output)
            guard outside.isEmpty else {
                throw QualityError.gateFailed("\(module) needs \(outside.joined(separator: ", ")), outside libc")
            }
            objects.append(object)
            nmOutput += symbols.output
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
}
