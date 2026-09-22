import { isHoliday } from '@/lib/holidays'

export type DayKind = 'work' | 'weekend' | 'holiday' | 'custom-off' | 'custom-work'

export interface DayCell {
  /** 'YYYY-MM-DD' */
  date: string
  day: number
  /** 0=일 … 6=토 */
  dow: number
  kind: DayKind
  /** 근무일로 세는 날인지 */
  isWorkday: boolean
}

export function dateKey(year: number, month: number, day: number): string {
  return `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`
}

/** 아무 것도 지정하지 않았을 때 쉬는 날인가 — 주말이거나 공휴일 */
export function isDefaultOff(year: number, month: number, day: number): boolean {
  const dow = new Date(year, month, day).getDay()
  if (dow === 0 || dow === 6) return true
  return isHoliday(year, month, day)
}

/**
 * 그 달의 날짜별 상태.
 *
 * overrides는 "기본값을 뒤집은 날"의 목록이다. 쉬는 날을 더하는 것과
 * 공휴일에 출근한 것을 같은 방식으로 담을 수 있다.
 */
export function monthCells(year: number, month: number, overrides: readonly string[]): DayCell[] {
  const flipped = new Set(overrides)
  const daysInMonth = new Date(year, month + 1, 0).getDate()

  const cells: DayCell[] = []
  for (let day = 1; day <= daysInMonth; day += 1) {
    const date = dateKey(year, month, day)
    const dow = new Date(year, month, day).getDay()
    const defaultOff = isDefaultOff(year, month, day)
    const isFlipped = flipped.has(date)
    const off = isFlipped ? !defaultOff : defaultOff

    let kind: DayKind
    if (isFlipped) {
      kind = off ? 'custom-off' : 'custom-work'
    } else if (dow === 0 || dow === 6) {
      kind = 'weekend'
    } else if (defaultOff) {
      kind = 'holiday'
    } else {
      kind = 'work'
    }

    cells.push({ date, day, dow, kind, isWorkday: !off })
  }
  return cells
}

/** 달력 기준 그 달의 근무일수 */
export function workdaysFromCalendar(
  year: number,
  month: number,
  overrides: readonly string[],
): number {
  return monthCells(year, month, overrides).filter((c) => c.isWorkday).length
}

/** 한 날짜의 기본값 뒤집기를 켜고 끈다 */
export function toggleOverride(overrides: readonly string[], date: string): string[] {
  return overrides.includes(date)
    ? overrides.filter((d) => d !== date)
    : [...overrides, date].sort()
}

/** 그 달에 해당하는 override만 남긴다 */
export function overridesInMonth(overrides: readonly string[], year: number, month: number) {
  const prefix = `${year}-${String(month + 1).padStart(2, '0')}-`
  return overrides.filter((d) => d.startsWith(prefix))
}

/** 그 달의 override를 모두 지운다 */
export function clearMonthOverrides(
  overrides: readonly string[],
  year: number,
  month: number,
): string[] {
  const prefix = `${year}-${String(month + 1).padStart(2, '0')}-`
  return overrides.filter((d) => !d.startsWith(prefix))
}
