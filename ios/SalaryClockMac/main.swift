import AppKit

/// Mac App Store 빌드의 진입점. macos/SalaryClockApp/Sources/SalaryClockApp/main.swift와
/// 같지만, 여기서는 앱 소스가 같은 모듈로 컴파일되므로 SalaryClockAppLib을
/// import하지 않는다.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// LSUIElement가 Info.plist에 있으므로 Dock에 뜨지 않는다.
app.setActivationPolicy(.accessory)
app.run()
