import Foundation
import Synchronization
import Testing

@testable import QualityKit

/// The real process runner and file system, on real processes and a temporary directory.
@Suite struct SystemTests {
    let here = URL(fileURLWithPath: NSTemporaryDirectory())

    @Test func aCommandsOutputErrorsAndStatusAreKeptApart() throws {
        let result = try ProcessRunner().run("/bin/sh", ["-c", "echo out; echo err >&2; exit 3"], in: here, echo: false)
        #expect(result == CommandResult(status: 3, output: "out\n", errors: "err\n"))
        #expect(!result.succeeded)
        #expect(CommandResult(status: 0).succeeded)
    }

    @Test func aCommandIsFoundOnPathByName() throws {
        let result = try ProcessRunner().run("printf", ["%s", "named"], in: here, echo: false)
        #expect(result.output == "named" && result.succeeded)
    }

    @Test func aCommandRunsInTheGivenDirectory() throws {
        let result = try ProcessRunner().run("/bin/pwd", [], in: URL(fileURLWithPath: "/usr"), echo: false)
        #expect(result.output == "/usr\n")
    }

    @Test func echoedOutputIsNotCaptured() throws {
        let result = try ProcessRunner().run("/usr/bin/true", [], in: here, echo: true)
        #expect(result == CommandResult(status: 0))
    }

    @Test func aMissingProgramIsUnavailable() {
        #expect(throws: QualityError.self) { try ProcessRunner().run("/no/such/program", [], in: here, echo: false) }
    }

    @Test func filesAreListedRelativeAndSortedWithoutHiddenOnes() throws {
        let directory = here.appendingPathComponent("winekit-fs-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let files = LocalFileSystem()
        try FileManager.default.createDirectory(
            at: directory.appendingPathComponent("b/c"),
            withIntermediateDirectories: true
        )
        for path in ["z.txt", "b/c/a.swift", ".hidden", "b/y.swift"] {
            try files.write(Data(path.utf8), to: directory.appendingPathComponent(path))
        }
        #expect(files.files(under: directory) == ["b/c/a.swift", "b/y.swift", "z.txt"])
        #expect(files.fileExists(directory.appendingPathComponent("b/y.swift")))
        #expect(!files.fileExists(directory.appendingPathComponent("nope")))
        #expect(try files.contents(directory.appendingPathComponent("z.txt")) == Data("z.txt".utf8))
        #expect(files.files(under: directory.appendingPathComponent("missing")).isEmpty)
    }

    @Test func theConsoleReporterMarksSteps() {
        let lines = Mutex<[String]>([])
        let reporter = ConsoleReporter { line in lines.withLock { $0.append(line) } }
        reporter.step("swift test")
        reporter.note("[OK] done")
        #expect(lines.withLock { $0 } == ["==> swift test", "[OK] done"])
    }
}
