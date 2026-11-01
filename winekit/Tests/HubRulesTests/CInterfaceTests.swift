import Testing

@testable import HubRules

/// The C entry point, called as ntdll calls it: byte strings with lengths, a C read callback, out-pointers.
@Suite struct CInterfaceTests {
    /// What the read callback reads: a buffer and its length, behind the context pointer.
    struct Blob {
        var base: UnsafeRawPointer
        var count: Int
    }

    static let readBlob: WineKitRead = { context, offset, buffer, count in
        guard let context, let buffer else { return -1 }
        let blob = context.assumingMemoryBound(to: Blob.self).pointee
        guard offset >= 0, Int(offset) < blob.count else { return 0 }
        let n = min(count, blob.count - Int(offset))
        buffer.copyMemory(from: blob.base + Int(offset), byteCount: n)
        return n
    }

    struct Output {
        var compatDB: String
        var dllDirectory: String?
        var messages: String
        var gate: Int32
    }

    func call(_ rules: String, exe: String = "Game.exe", file: [UInt8]? = nil, launcher: String = "") -> (Int32, Output)
    {
        var compatDB: UnsafeMutablePointer<CChar>?
        var dllDirectory: UnsafeMutablePointer<CChar>?
        var messages: UnsafeMutablePointer<CChar>?
        var gate: Int32 = -1
        let status: Int32 = rules.withCString { rulesPointer in
            exe.withCString { exePointer in
                launcher.withCString { launcherPointer in
                    let bytes = file ?? []
                    return bytes.withUnsafeBytes { raw in
                        var blob = Blob(base: raw.baseAddress ?? UnsafeRawPointer(bitPattern: 1)!, count: bytes.count)
                        return withUnsafeMutablePointer(to: &blob) { context in
                            winekitHubRulesApply(
                                rulesPointer,
                                rules.utf8.count,
                                exePointer,
                                exe.utf8.count,
                                file == nil ? nil : Self.readBlob,
                                context,
                                launcherPointer,
                                launcher.utf8.count,
                                &compatDB,
                                &dllDirectory,
                                &messages,
                                &gate
                            )
                        }
                    }
                }
            }
        }
        defer { [compatDB, dllDirectory, messages].forEach { winekitFree($0) } }
        let output = Output(
            compatDB: compatDB.map { String(cString: $0) } ?? "",
            dllDirectory: dllDirectory.map { String(cString: $0) },
            messages: messages.map { String(cString: $0) } ?? "",
            gate: gate
        )
        return (status, output)
    }

    @Test func rulesComeBackAsCStrings() {
        let (status, output) = call(
            "when exe=game.exe => x=1;hub_dll_dir=dxgi/a;gate_selector_fixup=true\nwhen nope",
            launcher: "v=3\nname=l"
        )
        #expect(status == 0)
        #expect(output.compatDB == "v=3\nname=hubrules-1;exe=Game.exe;x=1\nname=l")
        #expect(output.dllDirectory == "dxgi/a")
        #expect(output.gate == 1)
        #expect(
            output.messages
                == "Rhubrules: Game.exe matches line 1: x=1;hub_dll_dir=dxgi/a;gate_selector_fixup=true\nWline 2: no =>\n"
        )
    }

    @Test func noDllDirectoryIsNullAndNoGateIsZero() {
        let (_, output) = call("name=a")
        #expect(output.dllDirectory == nil && output.gate == 0 && output.messages.isEmpty)
    }

    @Test func factsAreReadThroughTheCallback() {
        let image: [UInt8] = {
            var bytes = [UInt8](repeating: 0, count: 0x200)
            bytes[0] = 0x4d
            bytes[1] = 0x5a
            bytes[0x3c] = 0x80
            bytes.replaceSubrange(0x80 ..< 0x84, with: [0x50, 0x45, 0, 0])
            bytes.replaceSubrange(0x84 ..< 0x86, with: [0x4c, 0x01])  // i386
            return bytes
        }()
        #expect(call("when machine=i386 => m=1", file: image).1.compatDB.contains("m=1"))
        #expect(!call("when machine=i386 => m=1").1.compatDB.contains("m=1"))  // no callback, no facts
        #expect(!call("when machine=i386 => m=1", file: [1, 2, 3]).1.compatDB.contains("m=1"))
    }

    @Test func aMissingOutputPointerIsRefused() {
        var compatDB: UnsafeMutablePointer<CChar>?
        var gate: Int32 = 0
        let status = winekitHubRulesApply(nil, 0, nil, 0, nil, nil, nil, 0, &compatDB, nil, nil, &gate)
        #expect(status == -1 && compatDB == nil)
    }

    @Test func emptyInputsNeedNoPointers() {
        var compatDB: UnsafeMutablePointer<CChar>?
        var dllDirectory: UnsafeMutablePointer<CChar>?
        var messages: UnsafeMutablePointer<CChar>?
        var gate: Int32 = 0
        #expect(winekitHubRulesApply(nil, 0, nil, 0, nil, nil, nil, 0, &compatDB, &dllDirectory, &messages, &gate) == 0)
        #expect(compatDB.map { String(cString: $0) } == "v=3")
        [compatDB, dllDirectory, messages].forEach { winekitFree($0) }
    }

    @Test func aFailingCallbackGivesNoFacts() {
        let failing: WineKitRead = { _, _, _, _ in -1 }
        let file = CallbackFile(reader: failing, context: nil)
        #expect(file.read(at: 0, count: 64).isEmpty)
        #expect(file.read(at: -1, count: 64).isEmpty)
        #expect(file.read(at: 0, count: 0).isEmpty)
    }
}
