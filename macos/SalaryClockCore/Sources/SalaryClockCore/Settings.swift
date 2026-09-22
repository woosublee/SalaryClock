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
        theme: ThemeMode = .light
    ) {
        self.payMode = payMode; self.payAmount = payAmount
        self.workDaysMode = workDaysMode; self.workDaysPerMonth = workDaysPerMonth
        self.dayOverrides = dayOverrides
        self.workStart = workStart; self.workEnd = workEnd
        self.lunchEnabled = lunchEnabled; self.lunchStart = lunchStart
        self.lunchMinutes = lunchMinutes
        self.netPay = netPay; self.deductionRate = deductionRate
        self.clockStyle = clockStyle; self.hideAmount = hideAmount; self.theme = theme
    }

    public static let `default` = Settings()
}

/// 웹 `lib/settings.ts`의 `ClockStyle` 유니언과 1:1로 맞아야 한다.
///
/// `clockStyle`이 Swift에서는 enum이 아니라 그냥 String이라(뷰가 아직
/// 하나뿐이라 굳이 enum으로 안 묶었다) 유효성 검사가 이 목록에 기대야 한다.
/// core가 "유효한 설정이 뭔지"를 정의하는 쪽이라 여기 둔다.
public let validClockStyles: Set<String> = [
    "minimal", "numerals", "grain", "rings", "sector",
    "dots", "countdown", "level", "sundial", "pulse",
]
