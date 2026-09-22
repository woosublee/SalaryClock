import {
  MS_PER_MINUTE,
  MS_PER_DAY,
  parseHHmm,
  durationMinutes,
  startOfLocalDay,
} from '@/lib/time'
import type { Settings } from '@/lib/settings'

export interface Shift {
  startMs: number
  endMs: number
  lunchStartMs: number | null
  lunchEndMs: number | null
  paidMs: number
}

function buildShift(s: Settings, dayStart: number): Shift {
  const workStartMin = parseHHmm(s.workStart)
  const shiftMin = durationMinutes(workStartMin, parseHHmm(s.workEnd))

  const startMs = dayStart + workStartMin * MS_PER_MINUTE
  const endMs = startMs + shiftMin * MS_PER_MINUTE

  let lunchStartMs: number | null = null
  let lunchEndMs: number | null = null
  let lunchMs = 0

  if (s.lunchEnabled) {
    const offsetMin = durationMinutes(workStartMin, parseHHmm(s.lunchStart))
    lunchStartMs = startMs + offsetMin * MS_PER_MINUTE
    lunchEndMs = lunchStartMs + s.lunchMinutes * MS_PER_MINUTE
    lunchMs = s.lunchMinutes * MS_PER_MINUTE
  }

  return { startMs, endMs, lunchStartMs, lunchEndMs, paidMs: endMs - startMs - lunchMs }
}

/** 그 시각을 품고 있으면 true. 시작은 포함, 끝은 제외. */
function contains(shift: Shift, now: number): boolean {
  return now >= shift.startMs && now < shift.endMs
}

/**
 * 화면에 보여줄 시프트.
 *
 *   1. now를 품는 시프트가 있으면        → 그것        (근무 중 · 점심)
 *   2. 없고, 오늘 안에 끝난 것이 있으면  → 그것        (퇴근 후 — 총액 유지)
 *   3. 그 외                              → 오늘 시작할 시프트 (출근 전 — 0원)
 *
 * 2단계가 없으면 퇴근 직후 19:00에 아무것도 안 걸려 적립액이 0으로 리셋된다.
 * "오늘 안에 끝났는가"로 보는 것이 핵심이다. 예전 규칙은 "시간적으로 가장
 * 가까운 시프트"였는데, 자정을 넘겨도 어제 시프트가 계속 가장 가까워서
 * 어제 총액이 그대로 남았다.
 *
 * 자정을 특별히 다루지 않는데도 초기화가 나오고, 야간근무(22:00–06:00)는
 * 1단계에 걸려 자정에 끊기지 않는다.
 */
export function resolveShift(s: Settings, now: number): Shift {
  const today = startOfLocalDay(now)
  const yesterday = buildShift(s, today - MS_PER_DAY)
  const todayShift = buildShift(s, today)
  const tomorrow = buildShift(s, today + MS_PER_DAY)

  for (const c of [yesterday, todayShift, tomorrow]) {
    if (contains(c, now)) return c
  }

  const ended = [yesterday, todayShift]
    .filter((c) => c.endMs <= now && c.endMs > today)
    .sort((a, b) => b.endMs - a.endMs)
  if (ended.length > 0) return ended[0]

  return todayShift
}

/** 두 시각 사이의 유급 시간(ms). 시프트 밖은 잘라내고 점심은 뺀다. */
export function paidMsBetween(shift: Shift, from: number, to: number): number {
  const lo = Math.max(from, shift.startMs)
  const hi = Math.min(to, shift.endMs)
  if (hi <= lo) return 0

  let paid = hi - lo
  if (shift.lunchStartMs !== null && shift.lunchEndMs !== null) {
    const overlap = Math.min(hi, shift.lunchEndMs) - Math.max(lo, shift.lunchStartMs)
    if (overlap > 0) paid -= overlap
  }
  return paid
}
