import { describe, it, expect } from 'vitest'
import {
  dateKey,
  isDefaultOff,
  isDayOff,
  monthCells,
  workdaysFromCalendar,
  toggleOverride,
  overridesInMonth,
  clearMonthOverrides,
} from '@/lib/calendar'

// 2026년 9월: 30일, 1일이 화요일, 추석 연휴 9/24(목)·9/25(금)·9/26(토)
const SEP = { year: 2026, month: 8 }

describe('dateKey', () => {
  it('YYYY-MM-DD로 만든다', () => {
    expect(dateKey(2026, 8, 22)).toBe('2026-09-22')
    expect(dateKey(2026, 0, 1)).toBe('2026-01-01')
  })
})

describe('isDefaultOff — 기본으로 쉬는 날', () => {
  it('토요일은 쉰다', () => {
    expect(isDefaultOff(2026, 8, 26)).toBe(true)
  })

  it('일요일은 쉰다', () => {
    expect(isDefaultOff(2026, 8, 27)).toBe(true)
  })

  it('평일은 일한다', () => {
    expect(isDefaultOff(2026, 8, 22)).toBe(false)
  })

  it('평일에 걸린 공휴일은 쉰다 — 추석 9/24(목), 9/25(금)', () => {
    expect(isDefaultOff(2026, 8, 24)).toBe(true)
    expect(isDefaultOff(2026, 8, 25)).toBe(true)
  })

  it('설날 연휴도 쉰다', () => {
    expect(isDefaultOff(2026, 1, 16)).toBe(true)
    expect(isDefaultOff(2026, 1, 17)).toBe(true)
    expect(isDefaultOff(2026, 1, 18)).toBe(true)
  })

  it('공휴일 표가 없는 해는 주말만 쉰다', () => {
    expect(isDefaultOff(2030, 8, 24)).toBe(false)
  })
})

describe('monthCells', () => {
  const cells = monthCells(SEP.year, SEP.month, [])

  it('그 달의 날짜를 모두 만든다', () => {
    expect(cells).toHaveLength(30)
    expect(cells[0].date).toBe('2026-09-01')
    expect(cells[29].date).toBe('2026-09-30')
  })

  it('주말을 weekend로 표시한다', () => {
    expect(cells.find((c) => c.day === 26)?.kind).toBe('weekend')
  })

  it('공휴일을 holiday로 표시한다', () => {
    expect(cells.find((c) => c.day === 24)?.kind).toBe('holiday')
    expect(cells.find((c) => c.day === 25)?.kind).toBe('holiday')
  })

  it('평일을 work로 표시한다', () => {
    expect(cells.find((c) => c.day === 22)?.kind).toBe('work')
  })

  it('주말과 공휴일은 근무일이 아니다', () => {
    expect(cells.find((c) => c.day === 26)?.isWorkday).toBe(false)
    expect(cells.find((c) => c.day === 24)?.isWorkday).toBe(false)
    expect(cells.find((c) => c.day === 22)?.isWorkday).toBe(true)
  })
})

describe('monthCells — 사용자가 뒤집은 날', () => {
  it('평일을 쉬는 날로 만들 수 있다', () => {
    const cells = monthCells(SEP.year, SEP.month, ['2026-09-22'])
    const cell = cells.find((c) => c.day === 22)
    expect(cell?.kind).toBe('custom-off')
    expect(cell?.isWorkday).toBe(false)
  })

  it('공휴일에 출근한 것으로 되돌릴 수 있다', () => {
    const cells = monthCells(SEP.year, SEP.month, ['2026-09-25'])
    const cell = cells.find((c) => c.day === 25)
    expect(cell?.kind).toBe('custom-work')
    expect(cell?.isWorkday).toBe(true)
  })

  it('주말에 출근한 것으로 되돌릴 수 있다', () => {
    const cells = monthCells(SEP.year, SEP.month, ['2026-09-26'])
    const cell = cells.find((c) => c.day === 26)
    expect(cell?.kind).toBe('custom-work')
    expect(cell?.isWorkday).toBe(true)
  })

  it('다른 달의 override는 무시한다', () => {
    const cells = monthCells(SEP.year, SEP.month, ['2026-10-22'])
    expect(cells.find((c) => c.day === 22)?.kind).toBe('work')
  })
})

describe('workdaysFromCalendar', () => {
  it('아무것도 안 고르면 평일 − 공휴일과 같다', () => {
    expect(workdaysFromCalendar(SEP.year, SEP.month, [])).toBe(20)
  })

  it('하루를 쉬는 날로 찍으면 하루 줄어든다', () => {
    expect(workdaysFromCalendar(SEP.year, SEP.month, ['2026-09-22'])).toBe(19)
  })

  it('공휴일에 출근하면 하루 늘어난다', () => {
    expect(workdaysFromCalendar(SEP.year, SEP.month, ['2026-09-25'])).toBe(21)
  })

  it('연차 3일을 찍으면 17일이 된다', () => {
    const vacation = ['2026-09-21', '2026-09-22', '2026-09-23']
    expect(workdaysFromCalendar(SEP.year, SEP.month, vacation)).toBe(17)
  })

  it('2026년 2월은 설날이 빠져 17일이다', () => {
    expect(workdaysFromCalendar(2026, 1, [])).toBe(17)
  })
})

describe('toggleOverride', () => {
  it('없으면 넣는다', () => {
    expect(toggleOverride([], '2026-09-22')).toEqual(['2026-09-22'])
  })

  it('있으면 뺀다', () => {
    expect(toggleOverride(['2026-09-22'], '2026-09-22')).toEqual([])
  })

  it('정렬된 상태를 유지한다', () => {
    expect(toggleOverride(['2026-09-22'], '2026-09-01')).toEqual(['2026-09-01', '2026-09-22'])
  })
})

describe('overridesInMonth / clearMonthOverrides', () => {
  const all = ['2026-09-01', '2026-09-22', '2026-10-05']

  it('그 달 것만 고른다', () => {
    expect(overridesInMonth(all, 2026, 8)).toEqual(['2026-09-01', '2026-09-22'])
  })

  it('그 달 것만 지운다', () => {
    expect(clearMonthOverrides(all, 2026, 8)).toEqual(['2026-10-05'])
  })
})

describe('isDayOff', () => {
  const day = (y: number, m: number, d: number) => new Date(y, m, d, 12, 0, 0).getTime()

  it('평일은 쉬는 날이 아니다', () => {
    expect(isDayOff([], day(2026, 8, 22))).toBe(false)
  })

  it('토요일은 쉬는 날이다', () => {
    expect(isDayOff([], day(2026, 8, 26))).toBe(true)
  })

  it('일요일은 쉬는 날이다', () => {
    expect(isDayOff([], day(2026, 8, 27))).toBe(true)
  })

  it('평일 공휴일은 쉬는 날이다', () => {
    expect(isDayOff([], day(2026, 8, 24))).toBe(true)
  })

  it('override로 평일을 쉬는 날로 만든다', () => {
    expect(isDayOff(['2026-09-22'], day(2026, 8, 22))).toBe(true)
  })

  it('override로 공휴일에 출근한 것으로 만든다', () => {
    expect(isDayOff(['2026-09-24'], day(2026, 8, 24))).toBe(false)
  })

  it('하루 중 어느 시각이든 결과가 같다', () => {
    expect(isDayOff([], new Date(2026, 8, 26, 0, 0, 0).getTime())).toBe(true)
    expect(isDayOff([], new Date(2026, 8, 26, 23, 59, 59).getTime())).toBe(true)
  })
})
