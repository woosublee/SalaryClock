import AppKit
import SalaryClockAppLib

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// LSUIElement가 Info.plist에 있으므로 Dock에 뜨지 않는다.
app.setActivationPolicy(.accessory)
app.run()
