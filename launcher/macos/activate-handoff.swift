// Make a running process the active macOS app (roadmap 0016).
//
// usage: activate-handoff PID
//
// Since macOS 14 activation is cooperative: a process can only become active when the active app yields to it. A
// game started by a Windows store client through Wine is not started by the user, so its own activation request is
// ignored and keyboard focus stays with the previous app. This helper is a user-launched, regular app: it activates
// itself with a 1-pixel, fully transparent window, then yields activation to the target and activates it.
// Proven by hand on 2026-10-31 (archive/probes/20261031-activation-input-display/handoff.swift).
// Exit status: 0 when the target is active afterwards, 1 when it isn't, 2 on a bad argument.
import AppKit

guard CommandLine.arguments.count == 2, let pid = pid_t(CommandLine.arguments[1]) else {
    FileHandle.standardError.write("usage: activate-handoff PID\n".data(using: .utf8)!)
    exit(2)
}
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1), styleMask: [.borderless],
                      backing: .buffered, defer: false)
window.alphaValue = 0
window.orderFront(nil)
DispatchQueue.main.async {
    app.activate()
    window.makeKeyAndOrderFront(nil)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        guard let target = NSRunningApplication(processIdentifier: pid) else {
            print("activate-handoff: no process \(pid)")
            exit(1)
        }
        app.yieldActivation(to: target)
        _ = target.activate(from: NSRunningApplication.current, options: [.activateAllWindows])
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("activate-handoff: pid \(pid) active=\(target.isActive)")
            exit(target.isActive ? 0 : 1)
        }
    }
}
app.run()
