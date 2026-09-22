import type { Settings } from '@/lib/settings'
import { hasHolidayData, weekdayHolidaysInMonth } from '@/lib/holidays'
import { workdaysFromCalendar } from '@/lib/calendar'

export interface WorkdayInfo {
  /** 그 달의 평일(월~금) 수 */
  weekdays: number
  /** 평일에 걸린 공휴일 수. 주말과 겹친 공휴일은 세지 않는다 */
  holidays: number
  /** 실제 근무일수 = 평일 − 평일 공휴일 */
  workdays: number
  /** 그 해 공휴일 표가 있는지. 없으면 holidays는 0이고 workdays는 평일 수와 같다 */
  hasHolidayData: boolean
}

/** 그 시각이 속한 달의 평일(월~금) 수 */
export function weekdaysInMonth(now: number): number {
  const d = new Date(now)
  const year = d.getFullYear()
  const month = d.getMonth()

  const daysInMonth = new Date(year, month + 1, 0).getDate()

  let count = 0
  for (let day = 1; day <= daysInMonth; day += 1) {
    const dow = new Date(year, month, day).getDay()
    if (dow !== 0 && dow !== 6) count += 1
  }
  return count
}

/**
 * 달마다 결과가 고정이므로 캐시해 둔다.
 * 이 함수는 rAF 틱마다 여러 번 호출되고, 한 번 돌 때 한 달치 Date를 만든다.
 * 초당 수천 개를 만들 이유가 없다.
 */
const cache = new Map<string, WorkdayInfo>()

export function workdayInfo(now: number): WorkdayInfo {
  const d = new Date(now)
  const year = d.getFullYear()
  const month = d.getMonth()

  const key = `${year}-${month}`
  const cached = cache.get(key)
  if (cached) return cached

  const weekdays = weekdaysInMonth(now)
  const holidays = weekdayHolidaysInMonth(year, month).length

  const info: WorkdayInfo = {
    weekdays,
    holidays,
    workdays: weekdays - holidays,
    hasHolidayData: hasHolidayData(year),
  }
  cache.set(key, info)
  return info
}

/**
 * 그 시각이 속한 달의 근무일수.
 * 공휴일 표가 있는 해는 평일에서 공휴일을 뺀다. 없는 해는 평일 수를 그대로 쓴다.
 */
export function workdaysInMonth(now: number): number {
  return workdayInfo(now).workdays
}

/**
 * 설정에 따른 이번 달 근무일수.
 *
 * auto     — 평일 − 공휴일
 * calendar — 달력에서 고른 것 (주말·공휴일 기본 휴무 + 사용자가 뒤집은 날)
 * manual   — 사용자가 넣은 숫자 그대로
 */
export function effectiveWorkDays(s: Settings, now: number): number {
  if (s.workDaysMode === 'manual') return s.workDaysPerMonth

  if (s.workDaysMode === 'calendar') {
    const d = new Date(now)
    return workdaysFromCalendar(d.getFullYear(), d.getMonth(), s.dayOverrides)
  }

  return workdaysInMonth(now)
}
