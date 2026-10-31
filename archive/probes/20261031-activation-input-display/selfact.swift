import AppKit
let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "legacy"
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let w = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 300, height: 120), styleMask: [.titled], backing: .buffered, defer: false)
w.title = "activation test (\(mode))"; w.orderFront(nil)
DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
    if mode == "legacy" { app.activate(ignoringOtherApps: true) } else { app.activate() }
    w.makeKeyAndOrderFront(nil)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        print("\(mode): isActive=\(app.isActive) frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "?")")
        exit(0)
    }
}
app.run()
