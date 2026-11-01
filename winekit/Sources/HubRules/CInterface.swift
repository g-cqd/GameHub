// The C interface of C/winekit.h: Wine's ntdll calls it, with the file reading, the environment and the PEB staying on
// the C side. Every pointer comes from the caller; the strings returned are allocated here and released by winekit_free.

/// `winekit_read_fn`: up to `count` bytes at `offset` into `buffer`, as pread.
public typealias WineKitRead = @convention(c) (UnsafeMutableRawPointer?, Int64, UnsafeMutableRawPointer?, Int) -> Int

/// The executable, read through the caller's callback: as safe as the callback is.
@unsafe struct CallbackFile: PEFile {
    let reader: WineKitRead
    let context: UnsafeMutableRawPointer?

    func read(at offset: Int, count: Int) -> Bytes {
        guard offset >= 0, count > 0 else { return [] }
        var buffer = Bytes(repeating: 0, count: count)
        let got = buffer.withUnsafeMutableBytes { bytes in
            unsafe reader(context, Int64(offset), bytes.baseAddress, count)
        }
        return got > 0 ? Bytes(buffer.prefix(got)) : []
    }
}

/// `winekit_hub_rules_apply`; see C/winekit.h.
// The C signature fixes the parameters: each byte string with its length and an out-pointer per result, since a Swift
// struct has no layout C can rely on.
@_cdecl("winekit_hub_rules_apply")
// swiftlint:disable:next function_parameter_count
public func winekitHubRulesApply(
    _ rules: UnsafePointer<CChar>?,
    _ rulesLength: Int,
    _ exe: UnsafePointer<CChar>?,
    _ exeLength: Int,
    _ read: WineKitRead?,
    _ context: UnsafeMutableRawPointer?,
    _ launcher: UnsafePointer<CChar>?,
    _ launcherLength: Int,
    _ compatDB: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?,
    _ dllDirectory: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?,
    _ messages: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?,
    _ gateSelectorFixup: UnsafeMutablePointer<Int32>?
) -> Int32 {
    guard let compatDB = unsafe compatDB, let dllDirectory = unsafe dllDirectory, let messages = unsafe messages,
        let gateSelectorFixup = unsafe gateSelectorFixup
    else { return -1 }
    let facts = unsafe read.flatMap { reader in
        unsafe PEFacts.read(from: CallbackFile(reader: reader, context: context))
    }
    let result = RulesEngine.apply(
        rules: unsafe copy(rules, rulesLength),
        exe: unsafe copy(exe, exeLength),
        facts: facts,
        launcher: unsafe copy(launcher, launcherLength)
    )
    unsafe compatDB.pointee = unsafe cString(result.compatDB)
    unsafe dllDirectory.pointee = unsafe result.dllDirectory.map { unsafe cString($0) }
    unsafe messages.pointee = unsafe cString(result.messages.flatMap { $0.line })
    unsafe gateSelectorFixup.pointee = result.gateSelectorFixup ? 1 : 0
    return 0
}

/// `winekit_free`: releases a string winekit_hub_rules_apply returned.
@_cdecl("winekit_free")
public func winekitFree(_ pointer: UnsafeMutableRawPointer?) {
    unsafe pointer?.deallocate()
}

/// The `length` bytes at `pointer`, or none.
private func copy(_ pointer: UnsafePointer<CChar>?, _ length: Int) -> Bytes {
    guard let pointer = unsafe pointer, length > 0 else { return [] }
    return unsafe Bytes(UnsafeRawBufferPointer(start: pointer, count: length))
}

/// A NUL-terminated copy of `bytes`, for winekit_free.
private func cString(_ bytes: Bytes) -> UnsafeMutablePointer<CChar> {
    let string = UnsafeMutablePointer<CChar>.allocate(capacity: bytes.count + 1)
    for (index, byte) in bytes.enumerated() { unsafe string[index] = CChar(bitPattern: byte) }
    unsafe string[bytes.count] = 0
    return unsafe string
}
