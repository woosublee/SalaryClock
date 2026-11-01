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

/// 앱이 보는 "지금". 평소엔 기기 시각 그대로다.
///
/// App Store 스크린샷은 금액이 올라가는 평일 근무 시간 화면이어야 하는데, 시뮬레이터는
/// 맥 시계를 그대로 써서 주말·밤에는 찍을 수 없다. 개발 빌드에서만 실행 인자
/// `-screenshotNow 2026-11-04T14:24:05`(기기 시간대)를 읽어 그 시각으로 옮긴다.
/// 시작할 때의 차이만큼만 옮기므로 초침은 그대로 흐른다.
enum AppClock {
    static let offset: TimeInterval = {
        #if DEBUG
        guard let text = UserDefaults.standard.string(forKey: "screenshotNow") else { return 0 }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f.date(from: text).map { $0.timeIntervalSinceNow } ?? 0
        #else
        return 0
        #endif
    }()

    static var now: Date { Date().addingTimeInterval(offset) }
    static func shifted(_ date: Date) -> Date { date.addingTimeInterval(offset) }
}
