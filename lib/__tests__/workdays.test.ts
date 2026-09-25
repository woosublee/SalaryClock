import { describe, it, expect } from 'vitest'
import { workdaysInMonth, weekdaysInMonth, workdayInfo, effectiveWorkDays } from '@/lib/workdays'
import { DEFAULT_SETTINGS, type Settings } from '@/lib/settings'
import { computeEarnings } from '@/lib/salary'
import { resolveShift } from '@/lib/shift'

const on = (y: number, m: number, d: number) => new Date(y, m - 1, d, 12).getTime()

describe('weekdaysInMonth — 주말만 제외', () => {
  it('2026년 9월은 평일 22일이다 (30일, 1일이 화요일)', () => {
    expect(weekdaysInMonth(on(2026, 9, 22))).toBe(22)
  })

  it('2026년 2월은 평일 20일이다', () => {
    expect(weekdaysInMonth(on(2026, 2, 10))).toBe(20)
  })

  it('달 안의 어느 날짜를 주든 같은 값이 나온다', () => {
    expect(weekdaysInMonth(on(2026, 9, 1))).toBe(weekdaysInMonth(on(2026, 9, 30)))
  })

  it('주말에 물어봐도 그 달의 평일 수를 센다', () => {
    // 2026-09-26은 토요일
    expect(weekdaysInMonth(on(2026, 9, 26))).toBe(22)
  })
})

describe('workdaysInMonth — 공휴일까지 제외', () => {
  it('2026년 9월은 추석(9/24 목, 9/25 금)이 빠져 20일이다', () => {
    expect(workdaysInMonth(on(2026, 9, 22))).toBe(20)
  })

  it('2026년 2월은 설날 연휴 3일이 빠져 17일이다', () => {
    expect(workdaysInMonth(on(2026, 2, 10))).toBe(17)
  })

  it('2026년 4월은 공휴일이 없어 평일 수와 같다', () => {
    expect(workdaysInMonth(on(2026, 4, 15))).toBe(22)
  })

  it('2026년 10월은 개천절 대체(10/5)와 한글날(10/9)이 빠져 20일이다', () => {
    expect(workdaysInMonth(on(2026, 10, 15))).toBe(20)
  })

  it('2027년 9월은 추석(9/14~16 화수목)이 빠진다', () => {
    expect(workdaysInMonth(on(2027, 9, 20))).toBe(weekdaysInMonth(on(2027, 9, 20)) - 3)
  })
})

describe('workdaysInMonth — 주말과 겹친 공휴일', () => {
  it('토요일에 걸린 공휴일은 세지 않는다', () => {
    // 2026-06-06 현충일은 토요일이라 평일이 줄지 않는다
    const info = workdayInfo(on(2026, 6, 15))
    expect(info.holidays).toBe(0)
    expect(info.workdays).toBe(info.weekdays)
  })

  it('추석 연휴 중 토요일(9/26)은 세지 않아 9월 공휴일은 2일이다', () => {
    expect(workdayInfo(on(2026, 9, 22)).holidays).toBe(2)
  })
})

describe('workdayInfo — 공휴일 표가 없는 해', () => {
  it('표에 없는 해는 평일 수로 되돌아간다', () => {
    const info = workdayInfo(on(2031, 9, 15))
    expect(info.hasHolidayData).toBe(false)
    expect(info.holidays).toBe(0)
    expect(info.workdays).toBe(info.weekdays)
  })

  it('표가 있는 해는 그렇다고 알려준다', () => {
    expect(workdayInfo(on(2026, 9, 22)).hasHolidayData).toBe(true)
    expect(workdayInfo(on(2027, 9, 22)).hasHolidayData).toBe(true)
    expect(workdayInfo(on(2030, 9, 22)).hasHolidayData).toBe(true)
  })
})

describe('effectiveWorkDays', () => {
  it('auto 모드에서는 그 달의 근무일수를 쓴다', () => {
    const s: Settings = { ...DEFAULT_SETTINGS, workDaysMode: 'auto' }
    expect(effectiveWorkDays(s, on(2026, 9, 22))).toBe(20)
    expect(effectiveWorkDays(s, on(2026, 2, 10))).toBe(17)
  })

  it('manual 모드에서는 설정값을 그대로 쓴다', () => {
    const s: Settings = { ...DEFAULT_SETTINGS, workDaysMode: 'manual', workDaysPerMonth: 21 }
    expect(effectiveWorkDays(s, on(2026, 9, 22))).toBe(21)
    expect(effectiveWorkDays(s, on(2026, 2, 10))).toBe(21)
  })
})

describe('effectiveWorkDays — 달력 모드', () => {
  const base: Settings = { ...DEFAULT_SETTINGS, workDaysMode: 'calendar' }

  it('아무것도 안 고르면 auto와 같다', () => {
    expect(effectiveWorkDays(base, on(2026, 9, 22))).toBe(20)
  })

  it('연차를 찍으면 그만큼 줄어든다', () => {
    const s: Settings = { ...base, dayOverrides: ['2026-09-21', '2026-09-22'] }
    expect(effectiveWorkDays(s, on(2026, 9, 15))).toBe(18)
  })

  it('공휴일 출근을 찍으면 늘어난다', () => {
    const s: Settings = { ...base, dayOverrides: ['2026-09-25'] }
    expect(effectiveWorkDays(s, on(2026, 9, 15))).toBe(21)
  })

  it('다른 달로 넘어가면 그 달 기준으로 다시 센다', () => {
    const s: Settings = { ...base, dayOverrides: ['2026-09-22'] }
    expect(effectiveWorkDays(s, on(2026, 10, 15))).toBe(20)
  })
})

describe('날짜 줄의 기준 달 — 근무일수와 같은 달이어야 한다', () => {
  // 2026년 4월은 평일 공휴일이 없고 5월은 있다. 기준이 어긋나면 값이 갈린다.
  it('월말 야간근무가 자정을 넘으면 시프트가 시작한 달로 센다', () => {
    const night: Settings = { ...DEFAULT_SETTINGS, workStart: '22:00', workEnd: '06:00', lunchEnabled: false }
    const afterMidnight = new Date(2026, 4, 1, 2, 0).getTime() // 5/1 02:00, 4/30 밤 근무 중
    expect(workdayInfo(afterMidnight)).not.toEqual(workdayInfo(on(2026, 4, 30)))

    const info = workdayInfo(resolveShift(night, afterMidnight).startMs)
    expect(info).toEqual(workdayInfo(on(2026, 4, 30)))
    expect(computeEarnings(night, afterMidnight).workDays).toBe(info.workdays)
  })
})
