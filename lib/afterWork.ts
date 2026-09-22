import { MS_PER_DAY, MS_PER_HOUR, startOfLocalDay } from '@/lib/time'
import { isDayOff } from '@/lib/calendar'
import { resolveShift } from '@/lib/shift'
import type { Settings } from '@/lib/settings'

/** 퇴근 후 보여줄 격려 문구의 종류. 문구 자체는 UI가 갖는다 */
export type AfterWorkKind = 'tomorrow' | 'restThisWeek' | 'nextWeek' | 'longBreak'

/** 일요일을 주의 시작으로 본 주 번호. 두 날이 같은 주인지만 비교하는 데 쓴다 */
function weekIndex(dayStart: number): number {
  const d = new Date(dayStart)
  return Math.floor((dayStart - d.getDay() * MS_PER_DAY) / MS_PER_DAY)
}

/**
 * 오늘 일을 마친 뒤, 다음 근무일이 언제인지로 격려 문구의 종류를 고른다.
 *
 * 기준일은 now가 아니라 방금 끝낸 시프트의 시작일이다 — 야간근무가 자정을
 * 넘겨 끝나도 "오늘 일한 날"은 시프트가 시작한 날이다.
 */
export function afterWorkKind(s: Settings, now: number): AfterWorkKind {
  const shift = resolveShift(s, now)
  const base = startOfLocalDay(shift.startMs)

  // 최대 30일까지만 찾는다. 그 안에 근무일이 없으면 긴 휴식으로 본다
  for (let gap = 1; gap <= 30; gap += 1) {
    // 정오를 더해 DST로 자정이 밀리는 지역에서도 안전 여유를 둔다 — 한국에는
    // DST가 없지만 isDayOff는 어차피 날짜만 보므로 결과는 같다.
    const day = base + gap * MS_PER_DAY + 12 * MS_PER_HOUR
    if (isDayOff(s.dayOverrides, day)) continue

    if (gap === 1) return 'tomorrow'
    if (gap >= 4) return 'longBreak'
    return weekIndex(startOfLocalDay(day)) === weekIndex(base) ? 'restThisWeek' : 'nextWeek'
  }
  return 'longBreak'
}
