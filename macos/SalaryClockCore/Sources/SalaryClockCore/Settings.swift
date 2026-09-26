import Foundation

public enum PayMode: String, Codable, Sendable { case annual, monthly, hourly }
public enum WorkDaysMode: String, Codable, Sendable { case auto, calendar, manual }
public enum ThemeMode: String, Codable, Sendable { case light, dark }

/// 웹 `lib/settings.ts`의 Settings와 필드 이름·타입이 1:1로 맞아야 한다.
/// shared/golden/settings.json이 이 구조로 그대로 디코드된다.
public struct Settings: Codable, Equatable, Sendable {
    public var payMode: PayMode
    public var payAmount: Double
    public var workDaysMode: WorkDaysMode
    public var workDaysPerMonth: Double
    public var dayOverrides: [String]
    public var workStart: String
    public var workEnd: String
    public var lunchEnabled: Bool
    public var lunchStart: String
    public var lunchMinutes: Int
    public var netPay: Bool
    public var deductionRate: Double?
    public var clockStyle: String
    public var hideAmount: Bool
    /// 금액을 가렸을 때 보이는 디지털 시각을 12시간제(오전/오후)로 쓸지
    public var hour12: Bool
    public var theme: ThemeMode

    public init(
        payMode: PayMode = .annual,
        payAmount: Double = 40_000_000,
        workDaysMode: WorkDaysMode = .auto,
        workDaysPerMonth: Double = 21,
        dayOverrides: [String] = [],
        workStart: String = "09:00",
        workEnd: String = "18:00",
        lunchEnabled: Bool = true,
        lunchStart: String = "12:00",
        lunchMinutes: Int = 60,
        netPay: Bool = false,
        deductionRate: Double? = nil,
        clockStyle: String = "minimal",
        hideAmount: Bool = false,
        hour12: Bool = false,
        theme: ThemeMode = .light
    ) {
        self.payMode = payMode; self.payAmount = payAmount
        self.workDaysMode = workDaysMode; self.workDaysPerMonth = workDaysPerMonth
        self.dayOverrides = dayOverrides
        self.workStart = workStart; self.workEnd = workEnd
        self.lunchEnabled = lunchEnabled; self.lunchStart = lunchStart
        self.lunchMinutes = lunchMinutes
        self.netPay = netPay; self.deductionRate = deductionRate
        self.clockStyle = clockStyle; self.hideAmount = hideAmount
        self.hour12 = hour12; self.theme = theme
    }

    public static let `default` = Settings()

    private enum CodingKeys: String, CodingKey {
        case payMode, payAmount, workDaysMode, workDaysPerMonth, dayOverrides
        case workStart, workEnd, lunchEnabled, lunchStart, lunchMinutes
        case netPay, deductionRate, clockStyle, hideAmount, hour12, theme
    }

    /// 빠진 필드는 기본값으로 채운다. 웹 `loadSettings`가 저장값을
    /// `DEFAULT_SETTINGS` 위에 덮어 읽는 것과 같다 — 필드가 하나 늘었다고
    /// 예전에 저장한 연봉과 달력을 통째로 버리지 않는다.
    ///
    /// 있는데 타입이 틀린 필드는 그대로 던진다. 웹도 그 경우는 검증에 실패해
    /// 기본값으로 돌아가므로 두 쪽이 같은 값을 살리고 같은 값을 버린다.
    /// `theme`이 빠졌을 때 기기 외형을 심는 일은 `SettingsStore`가 한다.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings.default
        payMode = try c.decodeIfPresent(PayMode.self, forKey: .payMode) ?? d.payMode
        payAmount = try c.decodeIfPresent(Double.self, forKey: .payAmount) ?? d.payAmount
        workDaysMode = try c.decodeIfPresent(WorkDaysMode.self, forKey: .workDaysMode) ?? d.workDaysMode
        workDaysPerMonth = try c.decodeIfPresent(Double.self, forKey: .workDaysPerMonth) ?? d.workDaysPerMonth
        dayOverrides = try c.decodeIfPresent([String].self, forKey: .dayOverrides) ?? d.dayOverrides
        workStart = try c.decodeIfPresent(String.self, forKey: .workStart) ?? d.workStart
        workEnd = try c.decodeIfPresent(String.self, forKey: .workEnd) ?? d.workEnd
        lunchEnabled = try c.decodeIfPresent(Bool.self, forKey: .lunchEnabled) ?? d.lunchEnabled
        lunchStart = try c.decodeIfPresent(String.self, forKey: .lunchStart) ?? d.lunchStart
        lunchMinutes = try c.decodeIfPresent(Int.self, forKey: .lunchMinutes) ?? d.lunchMinutes
        netPay = try c.decodeIfPresent(Bool.self, forKey: .netPay) ?? d.netPay
        deductionRate = try c.decodeIfPresent(Double.self, forKey: .deductionRate) ?? d.deductionRate
        clockStyle = try c.decodeIfPresent(String.self, forKey: .clockStyle) ?? d.clockStyle
        hideAmount = try c.decodeIfPresent(Bool.self, forKey: .hideAmount) ?? d.hideAmount
        hour12 = try c.decodeIfPresent(Bool.self, forKey: .hour12) ?? d.hour12
        theme = try c.decodeIfPresent(ThemeMode.self, forKey: .theme) ?? d.theme
    }
}

/// 웹 `lib/settings.ts`의 `ClockStyle` 유니언과 1:1로 맞아야 한다.
///
/// `clockStyle`은 Swift에서도 enum이 아니라 String이다. 골든이 이 필드를
/// 문자열로 고정하고 있고, 모르는 값이 저장돼 있어도 설정 전체의 디코딩이
/// 깨지지 않아야 한다 — 웹이 `FACES[style] ?? MinimalFace`로 받아넘기는 것과
/// 같은 태도다. 그래서 유효성 검사가 이 목록에 기댄다. core가 "유효한 설정이
/// 뭔지"를 정의하는 쪽이라 여기 둔다. 그리는 쪽의 enum은 앱 층의
/// `ClockStyle`이고, 이 목록과 1:1로 맞아야 한다.
public let validClockStyles: Set<String> = [
    "minimal", "numerals", "grain", "rings", "sector",
    "dots", "countdown", "level", "sundial", "pulse",
]
