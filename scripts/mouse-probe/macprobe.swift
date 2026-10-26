import AppKit
let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/mx/mac_events.log"
let seconds = CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2]) ?? 60 : 60
FileManager.default.createFile(atPath: path, contents: nil)
let out = FileHandle(forWritingAtPath: path)!
let t0 = Date()
func log(_ s: String) { out.write(String(format: "%6.0f ms  %@\n", Date().timeIntervalSince(t0) * 1000, s).data(using: .utf8)!) }
NSApplication.shared.setActivationPolicy(.prohibited)
let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp, .scrollWheel, .keyDown, .swipe, .smartMagnify, .systemDefined]
let watched: Set<UInt16> = [105, 107, 113, 106, 64, 79, 80, 90, 33, 30]   // F13-F20, [ and ]
_ = NSEvent.addGlobalMonitorForEvents(matching: mask) { e in
    switch e.type {
    case .scrollWheel:
        log("scroll dX \(e.scrollingDeltaX) dY \(e.scrollingDeltaY) precise \(e.hasPreciseScrollingDeltas) phase \(e.phase.rawValue) momentum \(e.momentumPhase.rawValue)")
    case .keyDown: if watched.contains(e.keyCode) { log("keyDown keyCode \(e.keyCode) modifiers \(e.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue)") }  // other keys are never logged
    case .swipe: log("swipe dX \(e.deltaX) dY \(e.deltaY)")
    case .smartMagnify: log("smartMagnify")
    case .systemDefined: if e.subtype.rawValue == 8 { log("media/aux key code \((e.data1 & 0xFFFF0000) >> 16) \((e.data1 & 0xFF00) == 0x0A00 ? "down" : "up")") }
    default: log("\(e.type.rawValue) buttonNumber \(e.buttonNumber) subtype \(e.subtype.rawValue)")
    }
}
log("macprobe ready (listening \(Int(seconds)) s)")
DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { log("done"); exit(0) }
NSApplication.shared.run()
