import Foundation

/// App Store 스크린샷용으로 처음부터 열어 둘 화면. scripts/appstore-screenshots.sh가
/// `-screenshot settings` 같은 실행 인자로 고른다.
///
/// 설정·달력은 버튼을 눌러야 열려서 시뮬레이터 명령만으로는 찍을 수 없다. 개발
/// 빌드에서만 읽는다 — App Store 빌드에는 이 경로가 아예 없다.
enum ScreenshotScene: String {
    case settings
    case calendar

    static let current: ScreenshotScene? = {
        #if DEBUG
        UserDefaults.standard.string(forKey: "screenshot").flatMap(ScreenshotScene.init(rawValue:))
        #else
        nil
        #endif
    }()
}
