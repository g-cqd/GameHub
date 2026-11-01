import Foundation
import PackagePlugin

/// `swift package wine-objects --output <dir>`: writes libwinekit.a and winekit.h into <dir> for Wine's build
/// (`make WINEKIT_DIR=<dir>`). The build and its checks are QualityKit's (`Request.wineObjects`); this passes paths.
@main
struct WineObjectsCommand: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        guard let flag = arguments.firstIndex(of: "--output"), flag + 1 < arguments.count else {
            Diagnostics.error("usage: swift package wine-objects --output <dir>")
            return
        }
        var call = ["wine-objects", arguments[flag + 1], "--package", context.package.directoryURL.path]
        if let swift = try? context.tool(named: "swift") {
            call += ["--toolchain", swift.url.deletingLastPathComponent().path]
        }
        let process = Process()
        process.executableURL = try context.tool(named: "winekit-quality").url
        process.arguments = call
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            Diagnostics.error("wine-objects failed (exit \(process.terminationStatus))")
        }
    }
}
