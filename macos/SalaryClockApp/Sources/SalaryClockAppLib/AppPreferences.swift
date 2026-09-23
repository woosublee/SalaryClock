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
    /// 설정 창의 위아래 버튼도 이 범위를 그대로 쓴다 — 검사와 조절이 같은
    /// 값을 보게 한다. 한쪽만 고치면 버튼으로는 넣을 수 있는데 저장은 거부되는
    /// 값이 생긴다.
    static let range: ClosedRange<Double> = 0.1...10
    public static let defaultInterval: Double = 1.0

    private let lock = NSLock()
    private var cached: Double

    private init() {
        cached = Self.load()
    }

    /// 유효한 값만 담긴다 — 무효한 값은 조용히 무시하고 직전 값을 지킨다.
    ///
    /// 검사를 `load()`에만 두면 "저장된 값은 유효하다"는 약속이 읽는 쪽에만
    /// 걸린다. 그러면 `0`이나 `NaN`이 들어왔을 때 그대로 저장되고, 그 값이
    /// 그대로 `startTimer(interval:)`에 넘어가 런루프가 도는 만큼 타이머가
    /// 깨어난다. 지금은 유일한 호출부(설정 창 저장 버튼)가 같은 `isValid`
    /// 뒤에 있어 일어나지 않지만, 불변식은 그 호출부가 아니라 여기서 지킨다.
    ///
    /// 범위로 자르지(clamp) 않는 이유는 둘이다. 하나, `NaN`은 자를 대상이
    /// 없어 어차피 특례가 필요하다. 둘, 자르면 사용자가 넣은 적 없는 값을
    /// 대신 저장하게 된다 — 직전 값은 적어도 사용자가 골랐던 유효한 값이다.
    /// 바뀐 게 없으므로 알림도 보내지 않는다(타이머를 헛되이 다시 걸지 않는다).
    public var menuBarInterval: Double {
        get { lock.withLock { cached } }
        set {
            guard Self.isValid(newValue) else { return }
            lock.withLock { cached = newValue }
            Self.save(newValue)
            NotificationCenter.default.post(name: .appPreferencesChanged, object: nil)
        }
    }

    public func reload() {
        lock.withLock { cached = Self.load() }
        NotificationCenter.default.post(name: .appPreferencesChanged, object: nil)
    }

    /// 저장된 값을 지우고 기본값으로 되돌린다. 설정 창의 초기화가 부른다 —
    /// 사용자에게는 같은 창의 한 항목이라 공유 설정만 되돌리면 절반만
    /// 초기화된다.
    public func reset() {
        UserDefaults.standard.removeObject(forKey: Self.key)
        reload()
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
