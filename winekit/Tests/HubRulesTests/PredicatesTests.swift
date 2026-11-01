import Testing

@testable import HubRules

@Suite struct PredicatesTests {
    let amd64 = PEFacts(
        machine: PEFacts.machineAMD64, sections: [Bytes(".text".utf8), Bytes(".bind".utf8)],
        imports: [Bytes("KERNEL32.dll".utf8), Bytes("d3d11".utf8)])

    func holds(_ list: String, exe: String = "Game.exe", facts: PEFacts?) -> Bool {
        Predicates.hold(Bytes(list.utf8)[...], exe: Bytes(exe.utf8), facts: facts)
    }

    @Test func exeMatchesWithoutCaseAndNeedsNoFacts() {
        #expect(holds("exe=game.EXE", facts: nil))
        #expect(!holds("exe=other.exe", facts: nil))
        #expect(!holds("exe=Game.ex", facts: nil))
    }

    @Test func machineNamesTheArchitecture() {
        #expect(holds("machine=amd64", facts: amd64))
        #expect(holds("machine=AMD64", facts: amd64))
        #expect(!holds("machine=i386", facts: amd64))
        #expect(!holds("machine=arm64", facts: amd64))
        #expect(!holds("machine=amd64", facts: nil))
        var i386 = amd64
        i386.machine = PEFacts.machineI386
        #expect(holds("machine=I386", facts: i386))
    }

    @Test func sectionNamesMatchExactly() {
        #expect(holds("section=.bind", facts: amd64))
        #expect(!holds("section=.BIND", facts: amd64))
        #expect(!holds("section=.tex", facts: amd64))
        #expect(!holds("section=.text", facts: nil))
    }

    @Test func importsAcceptTheNameWithOrWithoutDotDLL() {
        #expect(holds("imports=kernel32", facts: amd64))
        #expect(holds("imports=KERNEL32.DLL", facts: amd64))
        #expect(holds("imports=d3d11", facts: amd64))
        #expect(!holds("imports=d3d11.dll", facts: amd64))  // the import is "d3d11": no ".dll" to strip
        #expect(!holds("imports=kernel32.dl", facts: amd64))
        #expect(!holds("imports=kernel", facts: amd64))
        #expect(!holds("imports=kernel32", facts: nil))
    }

    @Test func everyListedImportMustBeThereAndEmptyItemsAreIgnored() {
        #expect(holds("imports=kernel32,d3d11", facts: amd64))
        #expect(!holds("imports=kernel32,user32", facts: amd64))
        #expect(holds("imports=,kernel32,", facts: amd64))
    }

    @Test func everyPredicateMustHold() {
        #expect(holds("exe=game.exe;machine=amd64;section=.text", facts: amd64))
        #expect(!holds("exe=game.exe;machine=i386", facts: amd64))
    }

    @Test func spacingAroundPredicatesIsIgnored() {
        #expect(holds("  exe=game.exe \t;  machine=amd64 ", facts: amd64))
        #expect(!holds("exe =game.exe", facts: amd64))  // the key is not trimmed
    }

    @Test func emptyListsAndFieldsHold() {
        #expect(holds("", facts: nil))
        #expect(holds(";; ;", facts: nil))
    }

    @Test func malformedOrUnknownPredicatesFail() {
        #expect(!holds("exe", facts: amd64))
        #expect(!holds("unknown=1", facts: amd64))
        #expect(!holds("exe=game.exe;bogus", facts: amd64))
    }
}
