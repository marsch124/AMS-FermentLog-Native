import CoreGraphics
import Foundation
// Prints "<windowID> <name>" for every normal on-screen window of the given process id (for `screencapture -l`).
let pid = Int32(CommandLine.arguments[1])!
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as! [[String: Any]]
for w in list where (w[kCGWindowOwnerPID as String] as? Int32) == pid && (w[kCGWindowLayer as String] as? Int) == 0 {
    print(w[kCGWindowNumber as String]!, w[kCGWindowName as String] ?? "-")
}
