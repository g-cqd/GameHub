import AppKit
let pid = pid_t(CommandLine.arguments[1])!
guard let app = NSRunningApplication(processIdentifier: pid) else { print("no app"); exit(1) }
let ok = app.activate(options: [.activateAllWindows])
RunLoop.current.run(until: Date().addingTimeInterval(1.0))
print("activate returned \(ok), now active=\(app.isActive), frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "?")")
