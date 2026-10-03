import SwiftUI

/// iOS 앱의 진입점. 맥은 메뉴바 팝오버로 띄우는 화면(PopoverView)을 여기서는
/// 창 하나에 꽉 채워 보여준다. 화면과 설정은 맥과 같은 소스를 쓴다 —
/// project.pbxproj가 macos/SalaryClockApp의 파일을 직접 가리킨다.
@main
struct SalaryClockApp: App {
    init() {
        // 첫 화면이 그려지기 전에 전에 받아 둔 공휴일 자료를 올려 둔다.
        _ = HolidayUpdater.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
