import Foundation

public extension Notification.Name {
    static let appPreferencesChanged = Notification.Name("dev.woosublee.salaryclock.appPreferencesChanged")
}

/// 맥 전용 표시 설정을 담는다. `Settings`(공유 도메인 모델)에 넣지 않는 이유는
/// `shared/golden/settings.json`이 그 구조를 고정하기 때문이다 — 필드를
/// 더하면 골든이 깨지고 웹 스키마까지 건드려야 한다. 여기 담기는 값은
/// 웹에 대응물이 없는, 메뉴바가 얼마나 자주 스스로를 다시 그리는가에 대한
/// 맥만의 표시 취향이라 별도 저장소를 둔다.
///
/// 구조는 `SettingsStore`를 그대로 옮긴 것이다: `UserDefaults`의 별도 키에
/// 저장하고, 저장된 값이 규칙을 어기면 기본값으로 되돌리고, 바뀌면 알림을
/// 보낸다.
public final class AppPreferences: @unchecked Sendable {
    public static let shared = AppPreferences()

    /// 테스트가 `UserDefaults.standard`에 직접 쓰고 지울 수 있도록 private로
    /// 감추지 않는다 — `@testable import`로만 보이는 internal이다.
    static let key = "menuBarInterval.v1"

    /// 0.1초보다 짧으면 배터리를, 10초보다 길면 "갱신"이라는 말이 무색해진다.
    private static let range: ClosedRange<Double> = 0.1...10
    public static let defaultInterval: Double = 1.0

    private let lock = NSLock()
    private var cached: Double

    private init() {
        cached = Self.load()
    }

    public var menuBarInterval: Double {
        get { lock.withLock { cached } }
        set {
            lock.withLock { cached = newValue }
            Self.save(newValue)
            NotificationCenter.default.post(name: .appPreferencesChanged, object: nil)
        }
    }

    public func reload() {
        lock.withLock { cached = Self.load() }
        NotificationCenter.default.post(name: .appPreferencesChanged, object: nil)
    }

    /// `0.1 <= interval <= 10`이고 유한해야 한다.
    public static func isValid(_ interval: Double) -> Bool {
        interval.isFinite && range.contains(interval)
    }

    private static func load() -> Double {
        // 키가 없으면 double(forKey:)는 0.0을 돌려준다. 0.0은 범위 밖이라
        // isValid가 자연히 걸러 기본값으로 돌아간다 — SettingsStore.load()가
        // 디코드 실패를 기본값으로 되돌리는 것과 같은 방침이다.
        let stored = UserDefaults.standard.double(forKey: key)
        guard isValid(stored) else { return defaultInterval }
        return stored
    }

    private static func save(_ interval: Double) {
        UserDefaults.standard.set(interval, forKey: key)
    }
}
