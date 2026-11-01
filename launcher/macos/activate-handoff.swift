// Make a game's Wine process the active macOS app (roadmap 0016).
//
// usage: activate-handoff PID...
//
// Since macOS 14 activation is cooperative: a process can only become active when the active app yields to it. A
// game started by a Windows store client through Wine is not started by the user, so its own activation request is
// ignored and keyboard focus stays with the previous app. This helper is a user-launched, regular app: it activates
// itself with a 1-pixel, fully transparent window, then yields activation to the target and activates it.
// Proven by hand on 2026-10-31 (archive/probes/20261031-activation-input-display/handoff.swift).
//
// The PIDs are candidates: a store starts a game through launchers and helpers, and only the process that shows the
// game's window may receive activation (HITMAN 3's Launcher.exe has no window; activating it took focus away from
// hitman3.exe). The target is the candidate owning the largest on-screen window, waited for up to 20 s. When the target
// is already the active app nothing happens, because the handoff itself deactivates it for a moment, which a
// fullscreen game sees as a focus loss.
//
// Exit status: 0 when the target is active afterwards, 1 when it isn't or no candidate shows a window, 2 on a bad
// argument.
import AppKit

let candidates = Set(CommandLine.arguments.dropFirst().compactMap { pid_t($0) })
guard !candidates.isEmpty, candidates.count == CommandLine.arguments.count - 1 else {
    FileHandle.standardError.write("usage: activate-handoff PID...\n".data(using: .utf8)!)
    exit(2)
}

/// The candidate owning the largest on-screen, normal-layer window of at least 100x100 points.
func windowOwner() -> pid_t? {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        as? [[String: Any]] ?? []
    var best: (pid: pid_t, area: Double)?
    for window in windows {
        guard let pid = window[kCGWindowOwnerPID as String] as? pid_t, candidates.contains(pid),
              window[kCGWindowLayer as String] as? Int == 0,
              let bounds = window[kCGWindowBounds as String] as? [String: Double],
              let width = bounds["Width"], let height = bounds["Height"], width >= 100, height >= 100
        else { continue }
        if best == nil || width * height > best!.area { best = (pid, width * height) }
    }
    return best?.pid
}

var owner: pid_t?
for _ in 0 ..< 40 {
    owner = windowOwner()
    if owner != nil { break }
    usleep(500_000)
}
guard let pid = owner, let target = NSRunningApplication(processIdentifier: pid) else {
    print("activate-handoff: no candidate shows a window (\(candidates.sorted()))")
    exit(1)
}
if target.isActive {
    print("activate-handoff: pid \(pid) is already active")
    exit(0)
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
        app.yieldActivation(to: target)
        _ = target.activate(from: NSRunningApplication.current, options: [.activateAllWindows])
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("activate-handoff: pid \(pid) active=\(target.isActive)")
            exit(target.isActive ? 0 : 1)
        }
    }
}
app.run()
