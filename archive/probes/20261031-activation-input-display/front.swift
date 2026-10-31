import AppKit
if let f = NSWorkspace.shared.frontmostApplication { print("frontmost: \(f.localizedName ?? "?") pid \(f.processIdentifier)") }
for a in NSWorkspace.shared.runningApplications where (a.localizedName ?? "").range(of: "\\.exe", options: [.regularExpression, .caseInsensitive]) != nil || a.executableURL?.path.contains("wine") == true {
    print("\(a.processIdentifier) active=\(a.isActive) policy=\(a.activationPolicy.rawValue) \(a.localizedName ?? "?")")
}
