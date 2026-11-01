// winekit-quality: WineKit's quality gates (QualityKit). `swift package quality …` runs it through the Quality plugin.
import Foundation
import QualityKit

do {
    let invocation = try Invocation.parse(
        Array(CommandLine.arguments.dropFirst()),
        environment: ProcessInfo.processInfo.environment,
        currentDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        home: FileManager.default.homeDirectoryForCurrentUser
    )
    let quality = Quality(
        workspace: invocation.workspace,
        runner: ProcessRunner(),
        fileSystem: LocalFileSystem(),
        reporter: ConsoleReporter(),
        platform: .current
    )
    try quality.run(invocation.request)
    print("[OK] \(invocation.request)")
} catch let error as QualityError {
    FileHandle.standardError.write(Data("[FAIL] \(error)\n".utf8))
    exit(error.exitStatus)
} catch {
    FileHandle.standardError.write(Data("[FAIL] \(error)\n".utf8))
    exit(2)
}
