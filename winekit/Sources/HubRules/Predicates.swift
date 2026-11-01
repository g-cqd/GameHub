// The predicates of a detection rule: `machine=i386|amd64`, `exe=<basename>`, `section=<name>`, `imports=<dll>[,<dll>...]`.

enum Predicates {
    static let known = ["exe", "machine", "section", "imports"].map { Bytes($0.utf8) }

    /// Whether every predicate of the ';'-separated list holds for the executable. An unknown predicate, one without '=',
    /// or a fact the headers couldn't give makes the rule not apply; an unknown one is also reported in `messages`.
    static func hold(_ list: ArraySlice<UInt8>, exe: Bytes, facts: PEFacts?, messages: inout [RulesMessage]) -> Bool {
        for field in ASCII.split(list, on: ASCII.semicolon) {
            let predicate = field.drop { $0 == ASCII.space }
            if predicate.isEmpty { continue }
            guard let equals = predicate.firstIndex(of: ASCII.equals) else { return false }
            let key = predicate[..<equals]
            var value = predicate[(equals + 1)...]
            while let last = value.last, last == ASCII.space || last == ASCII.tab { value = value.dropLast() }
            guard known.contains(where: { key.elementsEqual($0) }) else {
                messages.append(.warning(Bytes("unknown predicate ".utf8) + DebugString.quoted(key)))
                return false
            }
            guard holds(key: key, value: value, exe: exe, facts: facts) else { return false }
        }
        return true
    }

    private static func holds(key: ArraySlice<UInt8>, value: ArraySlice<UInt8>, exe: Bytes, facts: PEFacts?) -> Bool {
        if key.elementsEqual("exe".utf8) { return ASCII.equalsIgnoringCase(value, exe) }
        guard let facts else { return false }
        if key.elementsEqual("machine".utf8) {
            let want: UInt16? =
                ASCII.equalsIgnoringCase(value, "i386".utf8)
                ? PEFacts.machineI386 : ASCII.equalsIgnoringCase(value, "amd64".utf8) ? PEFacts.machineAMD64 : nil
            return want == facts.machine
        }
        if key.elementsEqual("section".utf8) { return facts.sections.contains { $0.elementsEqual(value) } }
        if key.elementsEqual("imports".utf8) {
            return ASCII.split(value, on: ASCII.comma).allSatisfy { $0.isEmpty || imports(facts, $0) }
        }
        return false
    }

    /// `d3d9` matches an import of `d3d9.dll` or `D3D9`, without regard to case.
    static func imports(_ facts: PEFacts, _ dll: ArraySlice<UInt8>) -> Bool {
        facts.imports.contains { name in
            ASCII.equalsIgnoringCase(name, dll)
                || (ASCII.hasPrefixIgnoringCase(name, dll)
                    && ASCII.equalsIgnoringCase(name.dropFirst(dll.count), ".dll".utf8))
        }
    }
}
