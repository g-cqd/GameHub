import Foundation
import PackagePlugin

/// `swift package quality <gate|fast|all|changed pre-commit|pre-push|wine-objects <dir>>`: runs winekit-quality on this
/// package with the pinned Aemi checkout. `wine-objects <dir>` writes libwinekit.a and winekit.h for Wine's build
/// (`make WINEKIT_DIR=<dir>`). Every decision is in QualityKit, which the tests cover; this only passes paths.
@main
struct QualityCommand: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let tool = try context.tool(named: "winekit-quality")
        // The plugin runs sandboxed: its work directory is where it may install the pinned tools.
        var call =
            arguments + [
                "--package", context.package.directoryURL.path, "--tool-cache",
                context.pluginWorkDirectoryURL.appendingPathComponent("tools").path
            ]
        // The toolchain running this plugin, so nested builds don't go through a toolchain manager's proxy.
        if let swift = try? context.tool(named: "swift") {
            call += ["--toolchain", swift.url.deletingLastPathComponent().path]
        }
        if let aemi = context.package.dependencies.first(where: { $0.package.id.lowercased() == "aemi" }) {
            call += ["--aemi", aemi.package.directoryURL.path]
        }
        let process = Process()
        process.executableURL = tool.url
        process.arguments = call
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            Diagnostics.error("quality \(arguments.joined(separator: " ")) failed (exit \(process.terminationStatus))")
            return
        }
    }
}
