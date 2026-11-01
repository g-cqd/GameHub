import Testing

@testable import HubRules

@Suite struct RulesEngineTests {
    let facts = PEFacts(machine: PEFacts.machineAMD64, sections: [Bytes(".text".utf8)], imports: [])

    func apply(_ rules: String, exe: String = "Game.exe", launcher: String = "") -> RulesResult {
        RulesEngine.apply(rules: Bytes(rules.utf8), exe: Bytes(exe.utf8), facts: facts, launcher: Bytes(launcher.utf8))
    }

    func text(_ result: RulesResult) -> String { String(decoding: result.compatDB, as: UTF8.self) }

    @Test func compatdbRulesPassThroughAfterTheHeader() {
        #expect(
            text(apply("name=a;exe=a.exe;dxgi=dxmt\n  \tname=b;exe=b.exe"))
                == "v=3\nname=a;exe=a.exe;dxgi=dxmt\nname=b;exe=b.exe"
        )
    }

    @Test func blankAndCommentLinesAreSkipped() {
        #expect(text(apply("\n# comment\n   \n\t# indented comment\n")) == "v=3")
    }

    @Test func carriageReturnsEndTheLine() {
        #expect(text(apply("name=a;exe=a.exe\r\nname=b\rjunk\n")) == "v=3\nname=a;exe=a.exe\nname=b")
    }

    @Test func aMatchingDetectionRuleBecomesACompatdbRuleNamedByItsLine() {
        let result = apply("# first\nwhen machine=amd64 => dxgi=dxmt;env=A=1")
        #expect(text(result) == "v=3\nname=hubrules-2;exe=Game.exe;dxgi=dxmt;env=A=1")
        #expect(result.matchedLines == [2])
        #expect(
            String(decoding: result.report, as: UTF8.self) == "hubrules: Game.exe matches line 2: dxgi=dxmt;env=A=1\n"
        )
    }

    @Test func line10AndLaterAreNumberedInDecimal() {
        let rules = String(repeating: "\n", count: 11) + "when exe=game.exe => x=1"
        #expect(text(apply(rules)) == "v=3\nname=hubrules-12;exe=Game.exe;x=1")
    }

    @Test func aDetectionRuleThatDoesNotMatchAddsNothing() {
        let result = apply("when machine=i386 => dxgi=dxmt")
        #expect(text(result) == "v=3")
        #expect(result.matchedLines.isEmpty)
        #expect(result.report.isEmpty)
    }

    @Test func aDetectionRuleWithoutAnArrowIsIgnored() {
        #expect(text(apply("when exe=game.exe dxgi=dxmt")) == "v=3")
    }

    @Test func onlyWhenFollowedByASpaceStartsADetectionRule() {
        #expect(text(apply("whenexe=game.exe => x=1")) == "v=3\nwhenexe=game.exe => x=1")
    }

    @Test func spacesAfterTheArrowAreDroppedAndTrailingOnesKept() {
        #expect(text(apply("when exe=game.exe =>    x=1  ")) == "v=3\nname=hubrules-1;exe=Game.exe;x=1  ")
    }

    @Test func theGateFixupIsACapabilityNotASetting() {
        let only = apply("when exe=game.exe => gate_selector_fixup=true")
        #expect(only.gateSelectorFixup)
        #expect(text(only) == "v=3")
        #expect(only.matchedLines == [1])
        let mixed = apply("when exe=game.exe => a=1;gate_selector_fixup=true;b=2")
        #expect(mixed.gateSelectorFixup)
        #expect(text(mixed) == "v=3\nname=hubrules-1;exe=Game.exe;a=1;b=2")
        #expect(!apply("when exe=game.exe => gate_selector_fixup=truex").gateSelectorFixup)
    }

    @Test func theReportShowsEachMatchAsWritten() {
        let result = apply(
            "when exe=game.exe =>   gate_selector_fixup=true;x=1  \nwhen exe=other.exe => y=1\nwhen exe=game.exe => z=1"
        )
        #expect(
            String(decoding: result.report, as: UTF8.self)
                == "hubrules: Game.exe matches line 1: gate_selector_fixup=true;x=1  \nhubrules: Game.exe matches line 3: z=1\n"
        )
    }

    @Test func onlyTheFirstGateFieldIsRemoved() {
        let result = apply("when exe=game.exe => gate_selector_fixup=true;gate_selector_fixup=true")
        #expect(text(result) == "v=3\nname=hubrules-1;exe=Game.exe;gate_selector_fixup=true")
    }

    @Test func theDllDirectoryIsTakenOutAndTheLastMatchWins() {
        let result = apply("when exe=game.exe => hub_dll_dir=dxgi/a\nwhen exe=game.exe => x=1;hub_dll_dir=dxgi/b")
        #expect(result.dllDirectory.map { String(decoding: $0, as: UTF8.self) } == "dxgi/b")
        #expect(text(result) == "v=3\nname=hubrules-2;exe=Game.exe;x=1")
    }

    @Test func aDllDirectoryOutsideLibWineIsRefused() {
        #expect(apply("when exe=game.exe => hub_dll_dir=../up").dllDirectory == nil)
        #expect(apply("when exe=game.exe => hub_dll_dir=a/../b").dllDirectory == nil)
        #expect(apply("when exe=game.exe => hub_dll_dir=/abs").dllDirectory == nil)
        let refused = apply("when exe=game.exe => hub_dll_dir=dxgi/ok\nwhen exe=game.exe => hub_dll_dir=/abs")
        #expect(refused.dllDirectory.map { String(decoding: $0, as: UTF8.self) } == "dxgi/ok")
    }

    @Test func anEmptyDllDirectoryIsASettingNotACapability() {
        let result = apply("when exe=game.exe => hub_dll_dir=")
        #expect(result.dllDirectory == nil)
        #expect(text(result) == "v=3\nname=hubrules-1;exe=Game.exe;hub_dll_dir=")
    }

    @Test func emptyFieldsBetweenSettingsAreKept() {
        #expect(text(apply("when exe=game.exe => a=1;;b=2;")) == "v=3\nname=hubrules-1;exe=Game.exe;a=1;;b=2;")
    }

    @Test func theLaunchersRulesComeLastWithoutTheirHeader() {
        #expect(text(apply("name=r", launcher: "v=3\nname=l")) == "v=3\nname=r\nname=l")
        #expect(text(apply("name=r", launcher: "v=3")) == "v=3\nname=r")
        #expect(text(apply("name=r", launcher: "name=l\n")) == "v=3\nname=r\nname=l\n")
        #expect(text(apply("name=r", launcher: "")) == "v=3\nname=r")
    }

    @Test func launcherRulesKeepEverythingAfterTheFirstLine() {
        #expect(RulesEngine.launcherRules(Bytes("v=3\na\nb".utf8)) == Bytes("a\nb".utf8))
        #expect(RulesEngine.launcherRules(Bytes("v=9".utf8)).isEmpty)
        #expect(RulesEngine.launcherRules(Bytes("name=x".utf8)) == Bytes("name=x".utf8))
    }

    @Test func decimalsHaveNoLeadingZeros() {
        #expect(ASCII.decimal(0) == Bytes("0".utf8))
        #expect(ASCII.decimal(7) == Bytes("7".utf8))
        #expect(ASCII.decimal(1_203) == Bytes("1203".utf8))
    }

    @Test func firstRangeFindsTheFirstOccurrence() {
        let hay = Bytes("a=>b=>c".utf8)[...]
        #expect(ASCII.firstRange(of: Bytes("=>".utf8), in: hay) == 1 ..< 3)
        #expect(ASCII.firstRange(of: Bytes("=>".utf8), in: hay.dropFirst(3)) == 4 ..< 6)
        #expect(ASCII.firstRange(of: Bytes("x".utf8), in: hay) == nil)
        #expect(ASCII.firstRange(of: [], in: hay) == nil)
        #expect(ASCII.firstRange(of: Bytes("ab".utf8), in: Bytes("a".utf8)[...]) == nil)
        #expect(ASCII.firstRange(of: Bytes("c".utf8), in: hay) == 6 ..< 7)
    }
}
