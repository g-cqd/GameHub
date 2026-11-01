public import Foundation

/// The command line of winekit-quality: a request and the workspace's paths.
///
///     winekit-quality <gate|fast|all|changed hook> --package <dir> [--aemi <dir>] [--tool-cache <dir>]
///                     [--wine-source <dir>] [--toolchain <bin dir>]
///
/// Without options: the current directory, no Aemi, ~/Library/Caches/winekit/tools, and WINE_SRC or ~/Developer/wine.
public struct Invocation: Equatable, Sendable {
    public var request: Request
    public var workspace: Workspace

    public static func parse(
        _ arguments: [String], environment: [String: String], currentDirectory: URL, home: URL
    ) throws -> Invocation {
        var rest: [String] = []
        var options: [String: String] = [:]
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            if ["--package", "--aemi", "--tool-cache", "--wine-source", "--toolchain"].contains(argument) {
                guard index + 1 < arguments.count else { throw QualityError.usage("\(argument) needs a value") }
                options[argument] = arguments[index + 1]
                index += 2
            } else {
                rest.append(argument)
                index += 1
            }
        }
        let url = { (path: String) in URL(fileURLWithPath: path) }
        let workspace = Workspace(
            root: options["--package"].map(url) ?? currentDirectory,
            aemi: options["--aemi"].map(url),
            toolCache: options["--tool-cache"].map(url) ?? home.appendingPathComponent("Library/Caches/winekit/tools"),
            wineSource: (options["--wine-source"] ?? environment["WINE_SRC"]).map(url)
                ?? home.appendingPathComponent("Developer/wine"),
            toolchain: options["--toolchain"].map(url))
        return Invocation(request: try Request.parse(rest), workspace: workspace)
    }
}
