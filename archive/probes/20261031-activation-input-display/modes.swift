import CoreGraphics
let d = CGMainDisplayID()
let opts = [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary
let cur = CGDisplayCopyDisplayMode(d)!
print("current: \(cur.width)x\(cur.height) pt, \(cur.pixelWidth)x\(cur.pixelHeight) px @ \(cur.refreshRate) Hz")
var seen = Set<String>()
for m in (CGDisplayCopyAllDisplayModes(d, opts) as! [CGDisplayMode]) where m.isUsableForDesktopGUI() {
    let k = "\(m.width)x\(m.height) pt -> \(m.pixelWidth)x\(m.pixelHeight) px @ \(Int(m.refreshRate)) Hz\(m.pixelWidth > m.width ? " (HiDPI)" : "")"
    if seen.insert(k).inserted { print(k) }
}
