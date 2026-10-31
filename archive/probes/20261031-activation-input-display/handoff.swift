import AppKit
let pid = pid_t(CommandLine.arguments[1])!
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1), styleMask: [.borderless], backing: .buffered, defer: false)
w.alphaValue = 0.0; w.orderFront(nil)
DispatchQueue.main.async {
    app.activate(); w.makeKeyAndOrderFront(nil)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        guard let target = NSRunningApplication(processIdentifier: pid) else { print("no target"); exit(1) }
        print("helper active=\(app.isActive)")
        app.yieldActivation(to: target)
        let ok = target.activate(from: NSRunningApplication.current, options: [.activateAllWindows])
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("activate(from:) returned \(ok); target active=\(target.isActive) frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "?")")
            exit(0)
        }
    }
}
app.run()
