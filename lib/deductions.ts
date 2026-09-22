/**
 * 실수령액 추정.
 *
 * 4대보험은 법정 요율이라 정확하게 계산된다.
 * 소득세는 간이세액표를 그대로 옮길 수 없어 연말정산 구조를 따라 근사한다.
 * 부양가족 수, 비과세 수당, 각종 공제가 빠져 있으므로 실제 명세서와는
 * 차이가 난다. 그래서 사용자가 공제율을 직접 덮어쓸 수 있어야 한다.
 */

export const RATES = {
  /** 국민연금 근로자 부담분 */
  pension: 0.045,
  /** 건강보험 근로자 부담분 */
  health: 0.03545,
  /** 장기요양보험 — 건강보험료에 곱한다 */
  longTermCare: 0.1295,
  /** 고용보험 근로자 부담분 */
  employment: 0.009,
} as const

/** 국민연금 기준소득월액 상·하한 */
const PENSION_CAP = 6_370_000
const PENSION_FLOOR = 390_000

/** 본인 기본공제 (연) */
const PERSONAL_DEDUCTION = 1_500_000

/** 지방소득세는 결정세액의 10% */
const LOCAL_TAX_RATE = 0.1

export interface Deductions {
  /** 국민연금 (월) */
  pension: number
  /** 건강보험 (월) */
  health: number
  /** 장기요양보험 (월) */
  longTermCare: number
  /** 고용보험 (월) */
  employment: number
  /** 소득세 + 지방소득세 (월, 추정) */
  incomeTax: number
  /** 월 공제 합계 */
  total: number
  /** 공제율 0..1 */
  rate: number
}

/** 근로소득공제 (연간 총급여 기준) */
function earnedIncomeDeduction(annualGross: number): number {
  if (annualGross <= 5_000_000) return annualGross * 0.7
  if (annualGross <= 15_000_000) return 3_500_000 + (annualGross - 5_000_000) * 0.4
  if (annualGross <= 45_000_000) return 7_500_000 + (annualGross - 15_000_000) * 0.15
  if (annualGross <= 100_000_000) return 12_000_000 + (annualGross - 45_000_000) * 0.05
  return 14_750_000 + (annualGross - 100_000_000) * 0.02
}

/** 종합소득세 누진세율 (과세표준 기준) */
function progressiveTax(taxBase: number): number {
  if (taxBase <= 14_000_000) return taxBase * 0.06
  if (taxBase <= 50_000_000) return taxBase * 0.15 - 1_260_000
  if (taxBase <= 88_000_000) return taxBase * 0.24 - 5_760_000
  if (taxBase <= 150_000_000) return taxBase * 0.35 - 15_440_000
  if (taxBase <= 300_000_000) return taxBase * 0.38 - 19_940_000
  if (taxBase <= 500_000_000) return taxBase * 0.4 - 25_940_000
  if (taxBase <= 1_000_000_000) return taxBase * 0.42 - 35_940_000
  return taxBase * 0.45 - 65_940_000
}

/** 근로소득 세액공제 한도 (총급여 구간별) */
function taxCreditCap(annualGross: number): number {
  if (annualGross <= 33_000_000) return 740_000
  if (annualGross <= 70_000_000) {
    return Math.max(660_000, 740_000 - (annualGross - 33_000_000) * 0.008)
  }
  if (annualGross <= 120_000_000) {
    return Math.max(500_000, 660_000 - (annualGross - 70_000_000) * 0.5)
  }
  return Math.max(200_000, 500_000 - (annualGross - 120_000_000) * 0.5)
}

/** 근로소득 세액공제 */
function earnedIncomeTaxCredit(calculatedTax: number, annualGross: number): number {
  const credit =
    calculatedTax <= 1_300_000
      ? calculatedTax * 0.55
      : 715_000 + (calculatedTax - 1_300_000) * 0.3

  return Math.min(credit, taxCreditCap(annualGross))
}

export function estimateDeductions(monthlyGross: number): Deductions {
  if (monthlyGross <= 0) {
    return {
      pension: 0,
      health: 0,
      longTermCare: 0,
      employment: 0,
      incomeTax: 0,
      total: 0,
      rate: 0,
    }
  }

  const pensionBase = Math.min(Math.max(monthlyGross, PENSION_FLOOR), PENSION_CAP)
  const pension = pensionBase * RATES.pension
  const health = monthlyGross * RATES.health
  const longTermCare = health * RATES.longTermCare
  const employment = monthlyGross * RATES.employment

  const annualGross = monthlyGross * 12
  const annualInsurance = (pension + health + longTermCare + employment) * 12

  const taxBase = Math.max(
    0,
    annualGross - earnedIncomeDeduction(annualGross) - PERSONAL_DEDUCTION - annualInsurance,
  )

  const calculatedTax = progressiveTax(taxBase)
  const finalTax = Math.max(0, calculatedTax - earnedIncomeTaxCredit(calculatedTax, annualGross))
  const incomeTax = (finalTax * (1 + LOCAL_TAX_RATE)) / 12

  const total = pension + health + longTermCare + employment + incomeTax

  return {
    pension,
    health,
    longTermCare,
    employment,
    incomeTax,
    total,
    rate: total / monthlyGross,
  }
}
