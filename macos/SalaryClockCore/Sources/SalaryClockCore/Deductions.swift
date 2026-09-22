import Foundation

/// 실수령액 추정.
///
/// 4대보험은 법정 요율이라 정확하게 계산된다.
/// 소득세는 간이세액표를 그대로 옮길 수 없어 연말정산 구조를 따라 근사한다.
/// 부양가족 수, 비과세 수당, 각종 공제가 빠져 있으므로 실제 명세서와는
/// 차이가 난다. 그래서 사용자가 공제율을 직접 덮어쓸 수 있어야 한다.

public enum DeductionRates {
    /// 국민연금 근로자 부담분
    public static let pension = 0.045
    /// 건강보험 근로자 부담분
    public static let health = 0.03545
    /// 장기요양보험 — 건강보험료에 곱한다
    public static let longTermCare = 0.1295
    /// 고용보험 근로자 부담분
    public static let employment = 0.009
}

/// 국민연금 기준소득월액 상·하한
private let PENSION_CAP = 6_370_000.0
private let PENSION_FLOOR = 390_000.0

/// 본인 기본공제 (연)
private let PERSONAL_DEDUCTION = 1_500_000.0

/// 지방소득세는 결정세액의 10%
private let LOCAL_TAX_RATE = 0.1

public struct Deductions: Sendable {
    /// 국민연금 (월)
    public let pension: Double
    /// 건강보험 (월)
    public let health: Double
    /// 장기요양보험 (월)
    public let longTermCare: Double
    /// 고용보험 (월)
    public let employment: Double
    /// 소득세 + 지방소득세 (월, 추정)
    public let incomeTax: Double
    /// 월 공제 합계
    public let total: Double
    /// 공제율 0..1
    public let rate: Double
}

/// 근로소득공제 (연간 총급여 기준)
private func earnedIncomeDeduction(_ annualGross: Double) -> Double {
    if annualGross <= 5_000_000 { return annualGross * 0.7 }
    if annualGross <= 15_000_000 { return 3_500_000 + (annualGross - 5_000_000) * 0.4 }
    if annualGross <= 45_000_000 { return 7_500_000 + (annualGross - 15_000_000) * 0.15 }
    if annualGross <= 100_000_000 { return 12_000_000 + (annualGross - 45_000_000) * 0.05 }
    return 14_750_000 + (annualGross - 100_000_000) * 0.02
}

/// 종합소득세 누진세율 (과세표준 기준)
private func progressiveTax(_ taxBase: Double) -> Double {
    if taxBase <= 14_000_000 { return taxBase * 0.06 }
    if taxBase <= 50_000_000 { return taxBase * 0.15 - 1_260_000 }
    if taxBase <= 88_000_000 { return taxBase * 0.24 - 5_760_000 }
    if taxBase <= 150_000_000 { return taxBase * 0.35 - 15_440_000 }
    if taxBase <= 300_000_000 { return taxBase * 0.38 - 19_940_000 }
    if taxBase <= 500_000_000 { return taxBase * 0.4 - 25_940_000 }
    if taxBase <= 1_000_000_000 { return taxBase * 0.42 - 35_940_000 }
    return taxBase * 0.45 - 65_940_000
}

/// 근로소득 세액공제 한도 (총급여 구간별)
private func taxCreditCap(_ annualGross: Double) -> Double {
    if annualGross <= 33_000_000 { return 740_000 }
    if annualGross <= 70_000_000 {
        return max(660_000, 740_000 - (annualGross - 33_000_000) * 0.008)
    }
    if annualGross <= 120_000_000 {
        return max(500_000, 660_000 - (annualGross - 70_000_000) * 0.5)
    }
    return max(200_000, 500_000 - (annualGross - 120_000_000) * 0.5)
}

/// 근로소득 세액공제
private func earnedIncomeTaxCredit(_ calculatedTax: Double, _ annualGross: Double) -> Double {
    let credit =
        calculatedTax <= 1_300_000
        ? calculatedTax * 0.55
        : 715_000 + (calculatedTax - 1_300_000) * 0.3

    return min(credit, taxCreditCap(annualGross))
}

public func estimateDeductions(_ monthlyGross: Double) -> Deductions {
    if monthlyGross <= 0 {
        return Deductions(
            pension: 0,
            health: 0,
            longTermCare: 0,
            employment: 0,
            incomeTax: 0,
            total: 0,
            rate: 0
        )
    }

    let pensionBase = min(max(monthlyGross, PENSION_FLOOR), PENSION_CAP)
    let pension = pensionBase * DeductionRates.pension
    let health = monthlyGross * DeductionRates.health
    let longTermCare = health * DeductionRates.longTermCare
    let employment = monthlyGross * DeductionRates.employment

    let annualGross = monthlyGross * 12
    let annualInsurance = (pension + health + longTermCare + employment) * 12

    let taxBase = max(
        0,
        annualGross - earnedIncomeDeduction(annualGross) - PERSONAL_DEDUCTION - annualInsurance
    )

    let calculatedTax = progressiveTax(taxBase)
    let finalTax = max(0, calculatedTax - earnedIncomeTaxCredit(calculatedTax, annualGross))
    let incomeTax = (finalTax * (1 + LOCAL_TAX_RATE)) / 12

    let total = pension + health + longTermCare + employment + incomeTax

    return Deductions(
        pension: pension,
        health: health,
        longTermCare: longTermCare,
        employment: employment,
        incomeTax: incomeTax,
        total: total,
        rate: total / monthlyGross
    )
}
