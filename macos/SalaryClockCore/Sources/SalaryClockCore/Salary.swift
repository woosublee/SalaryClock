import Foundation

public enum Phase: String, Sendable {
    case before, working, lunch, after, dayoff
}

public struct Earnings: Sendable {
    public let phase: Phase
    /// 오늘 지금까지 적립된 금액 (원)
    public let earned: Double
    /// 초당 적립액. 근무 중이 아니면 0
    public let perSecond: Double
    /// 유급시간 기준 진행률 0..1
    public let progress: Double
    public let elapsedPaidMs: Int
    public let totalPaidMs: Int
    /// 출근까지 남은 시간. 이미 출근했으면 0
    public let msUntilStart: Int
    /// 퇴근까지 남은 시계 시간(점심 포함). 퇴근했으면 0
    public let msUntilEnd: Int
    /// 점심 재개까지 남은 시간. 점심이 아니면 0
    public let msUntilLunchEnd: Int
    public let remainingAmount: Double
    /// 오늘 하루를 다 채웠을 때의 총액
    public let dailyTotal: Double
    public let workDays: Double
    public let deductionRate: Double
    public let isNet: Bool
    /// 휴무일이면 nil — 시계에 그릴 근무 구간이 없다
    public let shift: Shift?
}

/// 세전 월급 환산액. 공제율이 월 급여 기준이라 어떤 입력 방식이든 월 단위로 맞춘다.
public func monthlyGross(_ s: Settings, _ shift: Shift, _ workDays: Double) -> Double {
    if s.payMode == .annual { return s.payAmount / 12 }
    if s.payMode == .monthly { return s.payAmount }
    let paidHoursPerDay = Double(shift.paidMs) / 3_600_000
    return s.payAmount * paidHoursPerDay * workDays
}

/// 설정에 지정된 공제율이 있으면 그것을, 없으면 추정치를 쓴다.
public func deductionRateFor(_ s: Settings, _ gross: Double) -> Double {
    guard s.netPay else { return 0 }
    if let r = s.deductionRate { return r }
    return estimateDeductions(gross).rate
}

/// 초당 적립액.
///
/// 근무일수를 now가 아니라 shift.startMs 기준으로 센다. now로 세면 야간근무가
/// 월 경계를 넘는 순간 그 달의 근무일수가 바뀌어 금액이 튄다.
public func perSecondRate(_ s: Settings, _ shift: Shift) -> Double {
    let workDays = effectiveWorkDays(s, shift.startMs)
    let paidSecondsPerDay = Double(shift.paidMs) / 1000
    if paidSecondsPerDay <= 0 || workDays <= 0 { return 0 }

    let gross: Double =
        s.payMode == .hourly
        ? s.payAmount / 3600
        : monthlyGross(s, shift, workDays) / (workDays * paidSecondsPerDay)

    let rate = deductionRateFor(s, monthlyGross(s, shift, workDays))
    return gross * (1 - rate)
}

private func phaseOf(_ shift: Shift, _ now: Int) -> Phase {
    if now < shift.startMs { return .before }
    if now >= shift.endMs { return .after }
    if let ls = shift.lunchStartMs, let le = shift.lunchEndMs, now >= ls, now < le {
        return .lunch
    }
    return .working
}

public func computeEarnings(_ s: Settings, _ now: Int) -> Earnings {
    let shift = resolveShift(s, now)
    let workDays = effectiveWorkDays(s, shift.startMs)

    // 판정은 now가 아니라 시프트 시작일 기준이다. now로 보면 야간근무가 자정을
    // 넘는 순간 다음 날이 공휴일인지에 따라 근무 중에 0이 되어버린다.
    if isDayOff(s.dayOverrides, shift.startMs) {
        return Earnings(
            phase: .dayoff, earned: 0, perSecond: 0, progress: 0,
            elapsedPaidMs: 0,
            // 0이 아닌 이유: 설정 줄이 그날의 유급 시간을 계속 보여준다
            totalPaidMs: shift.paidMs,
            msUntilStart: 0, msUntilEnd: 0, msUntilLunchEnd: 0,
            remainingAmount: 0, dailyTotal: 0,
            workDays: workDays,
            deductionRate: deductionRateFor(s, monthlyGross(s, shift, workDays)),
            isNet: s.netPay, shift: nil
        )
    }

    let phase = phaseOf(shift, now)
    let rate = perSecondRate(s, shift)

    let totalPaidMs = shift.paidMs
    let elapsedPaidMs = paidMsBetween(shift, shift.startMs, now)
    let dailyTotal = rate * Double(totalPaidMs) / 1000
    let earned = rate * Double(elapsedPaidMs) / 1000

    return Earnings(
        phase: phase,
        earned: earned,
        perSecond: phase == .working ? rate : 0,
        progress: totalPaidMs == 0 ? 0 : Double(elapsedPaidMs) / Double(totalPaidMs),
        elapsedPaidMs: elapsedPaidMs,
        totalPaidMs: totalPaidMs,
        msUntilStart: max(0, shift.startMs - now),
        msUntilEnd: max(0, shift.endMs - now),
        msUntilLunchEnd: phase == .lunch ? max(0, (shift.lunchEndMs ?? now) - now) : 0,
        remainingAmount: max(0, dailyTotal - earned),
        dailyTotal: dailyTotal,
        workDays: workDays,
        deductionRate: deductionRateFor(s, monthlyGross(s, shift, workDays)),
        isNet: s.netPay,
        shift: shift
    )
}
