import Foundation
import Testing

@testable import QualityKit

@Suite struct InstallerTests {
    let tool = PinnedTool(name: "dolly", version: "0.13.0", macOSArm64SHA: sha, linuxX86SHA: nil)

    /// A runner whose download hashes to `digest` and whose installed binary reports `version`.
    func runner(digest: String = sha, version: String = "0.13.0") -> FakeRunner {
        FakeRunner { call in
            switch call.executable {
                case "shasum": CommandResult(status: 0, output: "\(digest)  /cache/x.tar.gz\n")
                case "/cache/dolly-0.13.0/dolly": CommandResult(status: 0, output: "\(version)\n")
                default: CommandResult(status: 0)
            }
        }
    }

    func installer(_ runner: FakeRunner, _ files: FakeFileSystem, _ platform: Platform = .macOSArm64) -> ToolInstaller {
        ToolInstaller(runner: runner, fileSystem: files, cache: toolCache, platform: platform)
    }

    @Test func anInstalledToolIsUsedAsItIs() throws {
        let files = FakeFileSystem(["/cache/dolly-0.13.0/dolly": ""])
        let runner = runner()
        #expect(try installer(runner, files).executable(for: tool, from: .gcqd).path == "/cache/dolly-0.13.0/dolly")
        #expect(runner.calls.isEmpty)
    }

    @Test func aMissingToolIsDownloadedCheckedAndInstalled() throws {
        let files = FakeFileSystem(["/cache/.download-dolly-0.13.0/dolly-0.13.0-macos-arm64/dolly": ""])
        let runner = runner()
        let installed = try installer(runner, files).executable(for: tool, from: .gcqd)
        #expect(installed.path == "/cache/dolly-0.13.0/dolly")
        let curl = try #require(runner.calls(to: "curl").first)
        #expect(
            curl.arguments.last
                == "https://github.com/g-cqd/dolly/releases/download/v0.13.0/dolly-0.13.0-macos-arm64.tar.gz"
        )
        let copy = try #require(runner.calls(to: "cp").first)
        #expect(
            copy.arguments == ["-R", "/cache/.download-dolly-0.13.0/dolly-0.13.0-macos-arm64/.", "/cache/dolly-0.13.0"]
        )
        #expect(runner.calls.last?.arguments == ["-rf", "/cache/.download-dolly-0.13.0"])  // the scratch is removed
    }

    @Test func anArchiveWithAnotherHashIsRefused() {
        let files = FakeFileSystem(["/cache/.download-dolly-0.13.0/dolly-0.13.0-macos-arm64/dolly": ""])
        let runner = runner(digest: otherSHA)
        #expect(throws: QualityError.unavailable("dolly: archive hash \(otherSHA) is not the pinned \(sha)")) {
            try installer(runner, files).executable(for: tool, from: .gcqd)
        }
        #expect(runner.calls(to: "tar").isEmpty)
    }

    @Test func aBinaryReportingAnotherVersionIsRemoved() {
        let files = FakeFileSystem(["/cache/.download-dolly-0.13.0/d/dolly": ""])
        let runner = runner(version: "0.12.0")
        #expect(throws: QualityError.unavailable("dolly reports '0.12.0', not 0.13.0")) {
            try installer(runner, files).executable(for: tool, from: .gcqd)
        }
        #expect(runner.calls(to: "rm").contains { $0.arguments == ["-rf", "/cache/dolly-0.13.0"] && !$0.echo })
        #expect(runner.calls.allSatisfy { !$0.echo })  // installing prints nothing
    }

    @Test func anArchiveWithoutTheBinaryIsRefused() {
        let files = FakeFileSystem(["/cache/.download-dolly-0.13.0/README": ""])
        #expect(throws: QualityError.unavailable("dolly: no binary in the archive")) {
            try installer(runner(), files).executable(for: tool, from: .gcqd)
        }
    }

    @Test func aPlatformWithoutAnArchiveIsUnavailable() {
        #expect(throws: QualityError.unavailable("dolly publishes no archive for this platform")) {
            try installer(runner(), FakeFileSystem(), .linuxX86).executable(for: tool, from: .gcqd)
        }
    }

    @Test func aFailedDownloadSaysSo() {
        let failing = FakeRunner { call in
            call.executable == "curl" ? CommandResult(status: 22, errors: "404\n") : CommandResult(status: 0)
        }
        #expect(throws: QualityError.unavailable("could not download dolly 0.13.0: 404")) {
            try installer(failing, FakeFileSystem()).executable(for: tool, from: .gcqd)
        }
    }

    @Test func releaseSourcesNameTheirArchives() {
        let mutation = PinnedTool(
            name: "swift-mutation-testing",
            version: "1.6.4",
            macOSArm64SHA: sha,
            linuxX86SHA: nil
        )
        #expect(
            ReleaseSource.swiftMutationTesting.url(mutation, .macOSArm64)
                == "https://github.com/ericodx/swift-mutation-testing/releases/download/v1.6.4/swift-mutation-testing-v1.6.4-macos.tar.gz"
        )
        #expect(ReleaseSource.gcqd.archiveName(tool, .linuxX86) == "dolly-0.13.0-linux-x86_64.tar.gz")
    }
}
