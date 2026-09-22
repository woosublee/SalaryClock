import { describe, it, expect } from 'vitest'
import { computeEarnings, perSecondRate } from '@/lib/salary'
import { resolveShift } from '@/lib/shift'
import { DEFAULT_SETTINGS, type Settings } from '@/lib/settings'

const at = (h: number, m = 0, s = 0) => new Date(2026, 8, 22, h, m, s, 0).getTime()
const HOUR = 3_600_000

// 기본 설정 09-18, 무급 점심 60분 → 하루 유급 8시간
const PAID_SECONDS_PER_DAY = 8 * 3600
// workDaysMode가 auto이므로 2026년 9월의 근무일수를 쓴다
// 평일 22일 − 추석 연휴 중 평일 2일(9/24 목, 9/25 금) = 20일
const WORK_DAYS = 20

describe('perSecondRate', () => {
  it('연봉을 12개월 × 근무일수 × 유급초로 나눈다', () => {
    const shift = resolveShift(DEFAULT_SETTINGS, at(14))
    const expected = 40_000_000 / (12 * WORK_DAYS * PAID_SECONDS_PER_DAY)
    expect(perSecondRate(DEFAULT_SETTINGS, shift, at(14))).toBeCloseTo(expected, 10)
  })

  it('월급은 12를 곱하지 않는다', () => {
    const s: Settings = { ...DEFAULT_SETTINGS, payMode: 'monthly', payAmount: 4_000_000 }
    const shift = resolveShift(s, at(14))
    expect(perSecondRate(s, shift, at(14))).toBeCloseTo(
      4_000_000 / (WORK_DAYS * PAID_SECONDS_PER_DAY),
      10,
    )
  })

  it('시급은 근무일수를 무시하고 3600으로 나눈다', () => {
    const s: Settings = {
      ...DEFAULT_SETTINGS,
      payMode: 'hourly',
      payAmount: 12_000,
      workDaysPerMonth: 1,
    }
    const shift = resolveShift(s, at(14))
    expect(perSecondRate(s, shift, at(14))).toBeCloseTo(12_000 / 3600, 10)
  })
})

describe('computeEarnings — phase 판정', () => {
  it('출근 전은 before', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(7)).phase).toBe('before')
  })

  it('근무 중은 working', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(10)).phase).toBe('working')
  })

  it('점심 중은 lunch', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(12, 30)).phase).toBe('lunch')
  })

  it('퇴근 후는 after', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(19)).phase).toBe('after')
  })

  it('점심 시작 정각은 lunch', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(12)).phase).toBe('lunch')
  })

  it('점심 종료 정각은 working', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(13)).phase).toBe('working')
  })
})

describe('computeEarnings — 금액', () => {
  it('출근 전에는 0원이다', () => {
    const e = computeEarnings(DEFAULT_SETTINGS, at(7))
    expect(e.earned).toBe(0)
    expect(e.perSecond).toBe(0)
    expect(e.progress).toBe(0)
  })

  it('근무 1시간 뒤에는 1시간치가 쌓인다', () => {
    const e = computeEarnings(DEFAULT_SETTINGS, at(10))
    const rate = perSecondRate(DEFAULT_SETTINGS, resolveShift(DEFAULT_SETTINGS, at(10)), at(10))
    expect(e.earned).toBeCloseTo(rate * 3600, 6)
  })

  it('점심 중에는 금액이 고정되고 초당 적립이 0이다', () => {
    const noon = computeEarnings(DEFAULT_SETTINGS, at(12))
    const mid = computeEarnings(DEFAULT_SETTINGS, at(12, 30))
    expect(mid.earned).toBeCloseTo(noon.earned, 6)
    expect(mid.perSecond).toBe(0)
  })

  it('점심이 끝나면 다시 쌓기 시작한다', () => {
    const before = computeEarnings(DEFAULT_SETTINGS, at(12, 59, 59))
    const after = computeEarnings(DEFAULT_SETTINGS, at(13, 0, 1))
    expect(after.earned).toBeGreaterThan(before.earned)
  })

  it('퇴근 후 금액은 하루치 총액과 같다', () => {
    const e = computeEarnings(DEFAULT_SETTINGS, at(19))
    expect(e.earned).toBeCloseTo(e.dailyTotal, 6)
    expect(e.remainingAmount).toBe(0)
  })

  it('하루치 총액은 연봉을 연간 근무일수로 나눈 값이다', () => {
    const e = computeEarnings(DEFAULT_SETTINGS, at(19))
    expect(e.dailyTotal).toBeCloseTo(40_000_000 / (12 * WORK_DAYS), 6)
  })
})

describe('computeEarnings — 진행률과 남은 시간', () => {
  it('출근 정각의 진행률은 0이다', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(9)).progress).toBe(0)
  })

  it('유급 절반 지점의 진행률은 0.5다', () => {
    // 09-12(3h) + 13-14(1h) = 4h = 유급 8h의 절반
    expect(computeEarnings(DEFAULT_SETTINGS, at(14)).progress).toBeCloseTo(0.5, 10)
  })

  it('퇴근 후 진행률은 1이다', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(19)).progress).toBe(1)
  })

  it('출근 전에는 msUntilStart가 출근까지 남은 시간이다', () => {
    const e = computeEarnings(DEFAULT_SETTINGS, at(7))
    expect(e.msUntilStart).toBe(2 * HOUR)
    expect(e.msUntilEnd).toBe(11 * HOUR)
  })

  it('근무 중에는 msUntilStart가 0이다', () => {
    const e = computeEarnings(DEFAULT_SETTINGS, at(10))
    expect(e.msUntilStart).toBe(0)
    expect(e.msUntilEnd).toBe(8 * HOUR)
  })

  it('퇴근 후에는 msUntilEnd가 0이다', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(19)).msUntilEnd).toBe(0)
  })

  it('점심 중에는 msUntilLunchEnd가 재개까지 남은 시간이다', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(12, 20)).msUntilLunchEnd).toBe(40 * 60_000)
  })

  it('점심이 아닐 때 msUntilLunchEnd는 0이다', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(10)).msUntilLunchEnd).toBe(0)
  })
})

describe('computeEarnings — 야간근무', () => {
  const night: Settings = {
    ...DEFAULT_SETTINGS,
    workStart: '22:00',
    workEnd: '06:00',
    lunchEnabled: false,
  }

  it('자정을 넘겨도 근무 중으로 본다', () => {
    expect(computeEarnings(night, at(3)).phase).toBe('working')
  })

  it('자정 이후 경과분이 이어서 쌓인다', () => {
    expect(computeEarnings(night, at(3)).progress).toBeCloseTo(5 / 8, 10)
  })
})

describe('computeEarnings — 근무일수', () => {
  it('auto 모드에서는 그 달의 근무일수를 쓴다', () => {
    expect(computeEarnings(DEFAULT_SETTINGS, at(14)).workDays).toBe(WORK_DAYS)
  })

  it('manual 모드에서는 설정값을 쓴다', () => {
    const s: Settings = { ...DEFAULT_SETTINGS, workDaysMode: 'manual', workDaysPerMonth: 20 }
    expect(computeEarnings(s, at(14)).workDays).toBe(20)
  })

  it('근무일수가 적은 달은 하루치가 더 크다', () => {
    const feb = new Date(2026, 1, 10, 14).getTime() // 근무일 17일 (설날 연휴)
    const sep = at(14) // 근무일 20일 (추석 연휴)
    expect(computeEarnings(DEFAULT_SETTINGS, feb).dailyTotal).toBeGreaterThan(
      computeEarnings(DEFAULT_SETTINGS, sep).dailyTotal,
    )
  })
})

describe('computeEarnings — 실수령 기준', () => {
  const net: Settings = { ...DEFAULT_SETTINGS, netPay: true }

  it('세전 기준에서는 공제율이 0이다', () => {
    const e = computeEarnings(DEFAULT_SETTINGS, at(14))
    expect(e.deductionRate).toBe(0)
    expect(e.isNet).toBe(false)
  })

  it('실수령 기준이면 금액이 줄어든다', () => {
    const gross = computeEarnings(DEFAULT_SETTINGS, at(14))
    const netted = computeEarnings(net, at(14))
    expect(netted.earned).toBeLessThan(gross.earned)
    expect(netted.isNet).toBe(true)
  })

  it('줄어든 비율이 공제율과 같다', () => {
    const gross = computeEarnings(DEFAULT_SETTINGS, at(14))
    const netted = computeEarnings(net, at(14))
    expect(netted.earned / gross.earned).toBeCloseTo(1 - netted.deductionRate, 10)
  })

  it('공제율을 직접 지정하면 추정치 대신 그 값을 쓴다', () => {
    const s: Settings = { ...net, deductionRate: 0.2 }
    const e = computeEarnings(s, at(14))
    expect(e.deductionRate).toBe(0.2)
    expect(e.earned).toBeCloseTo(computeEarnings(DEFAULT_SETTINGS, at(14)).earned * 0.8, 6)
  })
})

describe('computeEarnings — 하루 총액은 근무시간 길이와 무관하다', () => {
  // 월급제의 핵심 성질: 일급은 월급 ÷ 근무일수로 정해진다.
  // 그날 8시간을 일하든 7시간을 일하든 받는 돈은 같고, 초당 단가만 달라진다.
  const sevenHours: Settings = { ...DEFAULT_SETTINGS, lunchMinutes: 120 }

  it('무급 시간을 늘려도 하루 총액은 그대로다', () => {
    const eight = computeEarnings(DEFAULT_SETTINGS, at(19))
    const seven = computeEarnings(sevenHours, at(19))
    expect(seven.totalPaidMs).toBeLessThan(eight.totalPaidMs)
    expect(seven.dailyTotal).toBeCloseTo(eight.dailyTotal, 6)
  })

  it('대신 초당 적립액이 올라간다', () => {
    const eight = computeEarnings(DEFAULT_SETTINGS, at(10))
    const seven = computeEarnings(sevenHours, at(10))
    expect(seven.perSecond).toBeGreaterThan(eight.perSecond)
  })

  it('근무 구간을 줄여도 하루 총액은 그대로다', () => {
    const shortDay: Settings = { ...DEFAULT_SETTINGS, workEnd: '17:00' }
    expect(computeEarnings(shortDay, at(19)).dailyTotal).toBeCloseTo(
      computeEarnings(DEFAULT_SETTINGS, at(19)).dailyTotal,
      6,
    )
  })

  it('시급제는 반대다 — 적게 일하면 덜 번다', () => {
    const hourly: Settings = { ...DEFAULT_SETTINGS, payMode: 'hourly', payAmount: 20_000 }
    const eight = computeEarnings(hourly, at(19))
    const seven = computeEarnings({ ...hourly, lunchMinutes: 120 }, at(19))
    expect(seven.dailyTotal).toBeLessThan(eight.dailyTotal)
    expect(seven.perSecond).toBeCloseTo(eight.perSecond, 10)
  })
})
