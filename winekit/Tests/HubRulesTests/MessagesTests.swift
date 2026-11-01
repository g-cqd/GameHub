import Testing

@testable import HubRules

@Suite struct MessagesTests {
    func apply(_ rules: String) -> RulesResult {
        RulesEngine.apply(rules: Bytes(rules.utf8), exe: Bytes("Game.exe".utf8), facts: nil, launcher: [])
    }

    func text(_ message: RulesMessage) -> String {
        switch message {
            case .report(let bytes): "R " + String(decoding: bytes, as: UTF8.self)
            case .warning(let bytes): "W " + String(decoding: bytes, as: UTF8.self)
        }
    }

    @Test func warningsAndReportsComeInRuleOrder() {
        let result = apply(
            "when exe=game.exe => a=1\nwhen exe=game.exe no arrow\nwhen bogus=1 => b=1\nwhen exe=game.exe => hub_dll_dir=../x"
        )
        #expect(
            result.messages.map(text) == [
                "R hubrules: Game.exe matches line 1: a=1", "W line 2: no =>", "W unknown predicate \"bogus\"",
                "R hubrules: Game.exe matches line 4: hub_dll_dir=../x",
                "W line 4: hub_dll_dir=../x must be relative to lib/wine, ignored"
            ]
        )
    }

    @Test func anUnknownPredicateIsReportedEvenWithoutFacts() {
        #expect(apply("when exe=game.exe;colour=red => a=1").messages.map(text) == ["W unknown predicate \"colour\""])
        // the first failing predicate ends the rule: a later unknown one is never reached
        #expect(apply("when exe=other.exe;colour=red => a=1").messages.isEmpty)
    }

    @Test func messagesAreEncodedWithTheirKind() {
        #expect(RulesMessage.report(Bytes("x".utf8)).line == Bytes("Rx\n".utf8))
        #expect(RulesMessage.warning(Bytes("y".utf8)).line == Bytes("Wy\n".utf8))
    }

    @Test func debugStringsEscapeAsDebugstrA() {
        let quoted = DebugString.quoted(Bytes("a\n\r\t\"\\".utf8) + [0x01, 0x7f, 0xff, 0x20, 0x7e])
        #expect(String(decoding: quoted, as: UTF8.self) == #""a\n\r\t\"\\\x01\x7f\xff ~""#)
        #expect(DebugString.quoted([]) == Bytes("\"\"".utf8))
    }

    @Test func longDebugStringsStopWhereTheBufferEnds() {
        // debugstr_a's 300-byte buffer: one quote, then characters while at most 291 bytes are written, then "...".
        let long = DebugString.quoted(Bytes(repeating: UInt8(ascii: "a"), count: 400))
        #expect(long.count == 1 + 291 + 1 + 3)
        #expect(long.suffix(4) == Bytes("\"...".utf8))
        let fits = DebugString.quoted(Bytes(repeating: UInt8(ascii: "a"), count: 291))
        #expect(fits.count == 293 && fits.last == UInt8(ascii: "\""))
        // debugstr_a's quirk: the loop's `n--` runs even when the buffer stops it, so one byte over the limit is dropped
        // without "...", and only two over show it
        let oneOver = DebugString.quoted(Bytes(repeating: UInt8(ascii: "a"), count: 292))
        #expect(oneOver.count == 293 && oneOver.last == UInt8(ascii: "\""))
        let twoOver = DebugString.quoted(Bytes(repeating: UInt8(ascii: "a"), count: 293))
        #expect(twoOver.suffix(4) == Bytes("\"...".utf8))
        // escapes count: an escape that would cross the limit is still written whole
        let escapes = DebugString.quoted(Bytes(repeating: 0x01, count: 100))
        #expect(escapes.count == 1 + 73 * 4 + 1 + 3)
    }
}
