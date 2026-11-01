import Foundation
import Testing

@testable import QualityKit

@Suite struct ParsingTests {
    @Test func everyGateParsesByItsName() throws {
        for gate in Gate.allCases { #expect(try Request.parse([gate.rawValue]) == .gate(gate)) }
        #expect(try Request.parse(["fast"]) == .fast)
        #expect(try Request.parse(["all"]) == .all)
        #expect(try Request.parse(["mutation-baseline"]) == .mutationBaseline)
        #expect(try Request.parse(["wine-objects", "/out"]) == .wineObjects(output: "/out"))
        #expect(try Request.parse(["changed", "pre-commit"]) == .changed(.preCommit))
        #expect(try Request.parse(["changed", "pre-push"]) == .changed(.prePush))
    }

    @Test func malformedRequestsAreUsageErrors() {
        for arguments in [
            [], ["nope"], ["changed"], ["changed", "post-merge"], ["fast", "extra"], ["format", "x"], ["wine-objects"]
        ] {
            #expect(throws: QualityError.usage(Request.usage)) { try Request.parse(arguments) }
        }
    }

    @Test func allIsFastThenTheDynamicGates() {
        #expect(Request.fastGates == [.config, .manifest, .tags, .format, .lint, .analyzers])
        #expect(Request.allGates == Request.fastGates + [.test, .embedded, .differential])
    }

    @Test func invocationReadsOptionsAnywhere() throws {
        let invocation = try Invocation.parse(
            ["--package", "/p", "changed", "--aemi", "/a", "pre-push", "--tool-cache", "/c", "--wine-source", "/w"],
            environment: ["WINE_SRC": "/env"],
            currentDirectory: URL(fileURLWithPath: "/cwd"),
            home: URL(fileURLWithPath: "/h")
        )
        #expect(invocation.request == .changed(.prePush))
        #expect(invocation.workspace.toolchain == nil)
        let withToolchain = try Invocation.parse(
            ["test", "--toolchain", "/tc/bin"],
            environment: [:],
            currentDirectory: root,
            home: root
        )
        #expect(withToolchain.workspace.toolchain?.path == "/tc/bin")
        #expect(
            invocation.workspace
                == Workspace(
                    root: URL(fileURLWithPath: "/p"),
                    aemi: URL(fileURLWithPath: "/a"),
                    toolCache: URL(fileURLWithPath: "/c"),
                    wineSource: URL(fileURLWithPath: "/w")
                )
        )
    }

    @Test func invocationDefaults() throws {
        let home = URL(fileURLWithPath: "/h")
        let plain = try Invocation.parse(
            ["test"],
            environment: [:],
            currentDirectory: URL(fileURLWithPath: "/cwd"),
            home: home
        )
        #expect(plain.workspace.root.path == "/cwd")
        #expect(plain.workspace.aemi == nil)
        #expect(plain.workspace.toolCache.path == "/h/Library/Caches/winekit/tools")
        #expect(plain.workspace.wineSource?.path == "/h/Developer/wine")
        let fromEnvironment = try Invocation.parse(
            ["test"],
            environment: ["WINE_SRC": "/env"],
            currentDirectory: URL(fileURLWithPath: "/cwd"),
            home: home
        )
        #expect(fromEnvironment.workspace.wineSource?.path == "/env")
    }

    @Test func anOptionWithoutAValueIsAUsageError() {
        #expect(throws: QualityError.usage("--aemi needs a value")) {
            try Invocation.parse(["test", "--aemi"], environment: [:], currentDirectory: root, home: root)
        }
    }

    @Test func errorsMapToExitStatuses() {
        #expect(QualityError.gateFailed("x").exitStatus == 1)
        #expect(QualityError.unavailable("x").exitStatus == 2)
        #expect(QualityError.usage("x").exitStatus == 2)
        #expect(QualityError.gateFailed("message").description == "message")
    }

    @Test func locksReadAemisFormat() throws {
        let tools = try Lock.parse(
            "# comment\n\narcleak 0.15.0 \(sha) \(otherSHA)  # trailing\nmutation 1.6.4 \(sha) -\n"
        )
        #expect(
            tools == [
                PinnedTool(name: "arcleak", version: "0.15.0", macOSArm64SHA: sha, linuxX86SHA: otherSHA),
                PinnedTool(name: "mutation", version: "1.6.4", macOSArm64SHA: sha, linuxX86SHA: nil)
            ]
        )
    }

    @Test func malformedLockLinesAreRefused() {
        #expect(throws: QualityError.unavailable("lock line 2: expected 4 fields, found 3")) {
            try Lock.parse("# ok\narcleak 0.15.0 \(sha)")
        }
        #expect(throws: QualityError.unavailable("lock line 1: a hash is not 64 hexadecimal digits")) {
            try Lock.parse("arcleak 0.15.0 abc -")
        }
        // blank lines count: the error names the line as an editor shows it
        #expect(throws: QualityError.unavailable("lock line 3: expected 4 fields, found 1")) {
            try Lock.parse("\n\narcleak")
        }
        #expect(throws: QualityError.unavailable("lock line 1: a hash is not 64 hexadecimal digits")) {
            try Lock.parse("arcleak 0.15.0 \(sha.uppercased()) -")
        }
        #expect(throws: QualityError.unavailable("lock line 1: a hash is not 64 hexadecimal digits")) {
            try Lock.parse("arcleak 0.15.0 - \(sha)z")
        }
    }

    @Test func aRealAemiLockLineParses() throws {
        let line =
            "deadwood 0.13.0 93aaf921bda754c4e18790bd56d87ec222f592bea8ca6860d7f2d3a88f37cf19 "
            + "e964ef5e1cc397059692e680c9dd12bac1546e198f5873798f251fa30d42ac69"
        #expect(try Lock.parse(line).first?.version == "0.13.0")
    }
}
