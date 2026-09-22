import { describe, it, expect } from 'vitest'
import { estimateDeductions, RATES } from '@/lib/deductions'

describe('estimateDeductions — 4대보험', () => {
  const d = estimateDeductions(3_500_000)

  it('국민연금은 4.5%다', () => {
    expect(d.pension).toBeCloseTo(3_500_000 * 0.045, 0)
  })

  it('건강보험은 3.545%다', () => {
    expect(d.health).toBeCloseTo(3_500_000 * 0.03545, 0)
  })

  it('장기요양은 건강보험료의 12.95%다', () => {
    expect(d.longTermCare).toBeCloseTo(d.health * 0.1295, 0)
  })

  it('고용보험은 0.9%다', () => {
    expect(d.employment).toBeCloseTo(3_500_000 * 0.009, 0)
  })

  it('요율 상수가 노출된다', () => {
    expect(RATES.pension).toBe(0.045)
    expect(RATES.health).toBe(0.03545)
    expect(RATES.longTermCare).toBe(0.1295)
    expect(RATES.employment).toBe(0.009)
  })
})

describe('estimateDeductions — 국민연금 상·하한', () => {
  it('기준소득월액 상한을 넘으면 상한으로 막는다', () => {
    const high = estimateDeductions(20_000_000)
    expect(high.pension).toBeCloseTo(6_370_000 * 0.045, 0)
  })

  it('하한 아래면 하한으로 올린다', () => {
    const low = estimateDeductions(300_000)
    expect(low.pension).toBeCloseTo(390_000 * 0.045, 0)
  })
})

describe('estimateDeductions — 소득세', () => {
  it('저소득 구간에서는 소득세가 0에 가깝다', () => {
    const d = estimateDeductions(1_200_000)
    expect(d.incomeTax).toBeGreaterThanOrEqual(0)
    expect(d.incomeTax).toBeLessThan(30_000)
  })

  it('소득이 오르면 소득세도 오른다', () => {
    const low = estimateDeductions(3_000_000)
    const high = estimateDeductions(8_000_000)
    expect(high.incomeTax).toBeGreaterThan(low.incomeTax)
  })

  it('소득세는 음수가 되지 않는다', () => {
    expect(estimateDeductions(500_000).incomeTax).toBeGreaterThanOrEqual(0)
  })
})

describe('estimateDeductions — 합계와 공제율', () => {
  it('합계는 항목의 합이다', () => {
    const d = estimateDeductions(4_000_000)
    const sum = d.pension + d.health + d.longTermCare + d.employment + d.incomeTax
    expect(d.total).toBeCloseTo(sum, 6)
  })

  it('공제율은 합계 ÷ 세전 금액이다', () => {
    const d = estimateDeductions(4_000_000)
    expect(d.rate).toBeCloseTo(d.total / 4_000_000, 10)
  })

  it('일반적인 월급의 공제율은 8~25% 사이다', () => {
    for (const gross of [2_500_000, 3_500_000, 5_000_000, 8_000_000]) {
      const { rate } = estimateDeductions(gross)
      expect(rate).toBeGreaterThan(0.08)
      expect(rate).toBeLessThan(0.25)
    }
  })

  it('소득이 높을수록 공제율이 높다', () => {
    expect(estimateDeductions(9_000_000).rate).toBeGreaterThan(
      estimateDeductions(3_000_000).rate,
    )
  })

  it('세전이 0이면 전부 0이다', () => {
    const d = estimateDeductions(0)
    expect(d.total).toBe(0)
    expect(d.rate).toBe(0)
  })
})
