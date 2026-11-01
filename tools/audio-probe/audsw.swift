import CoreAudio
import Foundation
// audsw            : list output devices (* = default)
// audsw <id>       : make device <id> the default output
func prop<T>(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, _ v: inout T) -> OSStatus {
    var a = AudioObjectPropertyAddress(mSelector: sel, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    var size = UInt32(MemoryLayout<T>.size)
    return AudioObjectGetPropertyData(obj, &a, 0, nil, &size, &v)
}
var defAddr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
if CommandLine.arguments.count > 1, var id = AudioObjectID(CommandLine.arguments[1]) {
    let st = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defAddr, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &id)
    print("set default output to \(id): status \(st)")
    exit(st == 0 ? 0 : 1)
}
var def = AudioObjectID(0); _ = prop(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal, &def)
var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
var size: UInt32 = 0
AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size)
var ids = [AudioObjectID](repeating: 0, count: Int(size) / 4)
AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &ids)
for id in ids {
    var sa = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioObjectPropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
    var ss: UInt32 = 0
    AudioObjectGetPropertyDataSize(id, &sa, 0, nil, &ss)
    if ss == 0 { continue }
    var name: Unmanaged<CFString>? = nil
    _ = prop(id, kAudioObjectPropertyName, kAudioObjectPropertyScopeGlobal, &name)
    print("\(id == def ? "*" : " ") \(id)\t\(name?.takeRetainedValue() as String? ?? "?")")
}
