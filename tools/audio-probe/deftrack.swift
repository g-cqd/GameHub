import AudioToolbox
import AppKit
import Foundation
// Native reference: does a DefaultOutput unit's CurrentDevice follow a default-output change?
func current(_ u: AudioUnit) -> AudioObjectID {
    var id = AudioObjectID(0); var size = UInt32(4)
    AudioUnitGetProperty(u, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &id, &size)
    return id
}
func setDefault(_ v: AudioObjectID) {
    var id = v
    var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, 4, &id)
}
func work() {
let a = Int(CommandLine.arguments[1])!, b = Int(CommandLine.arguments[2])!
var desc = AudioComponentDescription(componentType: kAudioUnitType_Output, componentSubType: kAudioUnitSubType_DefaultOutput, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
var unit: AudioUnit? = nil
AudioComponentInstanceNew(AudioComponentFindNext(nil, &desc)!, &unit)
let env = ProcessInfo.processInfo.environment
if env["FMT"] != nil {
    var d = AudioStreamBasicDescription(mSampleRate: 44100, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked, mBytesPerPacket: 8, mFramesPerPacket: 1, mBytesPerFrame: 8, mChannelsPerFrame: 2, mBitsPerChannel: 32, mReserved: 0)
    print("format", AudioUnitSetProperty(unit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &d, UInt32(MemoryLayout<AudioStreamBasicDescription>.size)))
}
if env["LAYOUT"] != nil {
    var l = AudioChannelLayout(); l.mChannelLayoutTag = kAudioChannelLayoutTag_UseChannelBitmap; l.mChannelBitmap = AudioChannelBitmap(rawValue: 3)
    print("layout", AudioUnitSetProperty(unit!, kAudioUnitProperty_AudioChannelLayout, kAudioUnitScope_Input, 0, &l, UInt32(MemoryLayout<AudioChannelLayout>.size)))
}
var cb = AURenderCallbackStruct(inputProc: { _, flags, _, _, _, data in
    flags.pointee.insert(.unitRenderAction_OutputIsSilence)
    if let d = data { for buf in UnsafeMutableAudioBufferListPointer(d) { memset(buf.mData, 0, Int(buf.mDataByteSize)) } }
    return noErr }, inputProcRefCon: nil)
AudioUnitSetProperty(unit!, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &cb, UInt32(MemoryLayout<AURenderCallbackStruct>.size))
print("init", AudioUnitInitialize(unit!), "start", AudioOutputUnitStart(unit!))
print("unit on", current(unit!))
setDefault(AudioObjectID(b)); Thread.sleep(forTimeInterval: 2)
print("after default -> \(b): unit on", current(unit!))
setDefault(AudioObjectID(a)); Thread.sleep(forTimeInterval: 2)
print("after default -> \(a): unit on", current(unit!))

exit(0)
}
if ProcessInfo.processInfo.environment["WINE_LIKE"] != nil {
    // like Wine on macOS: the program runs on a secondary thread, the main thread sits in CFRunLoopRun
    if ProcessInfo.processInfo.environment["DISTCENTER"] != nil { _ = CFNotificationCenterGetDistributedCenter() }
    Thread.detachNewThread { work() }
    if ProcessInfo.processInfo.environment["NSAPP"] != nil { NSApplication.shared.run() } else { CFRunLoopRun() }
} else { work() }
