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

/** 진행 중이면 0, 아니면 시작 전·종료 후 중 가까운 쪽까지의 거리. */
function distanceTo(shift: Shift, now: number): number {
  if (now < shift.startMs) return shift.startMs - now
  if (now >= shift.endMs) return now - shift.endMs
  return 0
}

/**
 * now가 속한 시프트. 속한 것이 없으면 시간적으로 가장 가까운 시프트를 고른다.
 *
 * "가장 가까운"이 핵심이다. 퇴근 직후 19:00에 진행 중인 시프트만 찾으면
 * 아무것도 안 걸려 내일 시프트로 넘어가고, 그러면 적립액이 0으로 리셋된다.
 * 가까운 쪽을 고르면 방금 끝난 오늘 시프트가 잡혀 금액이 유지된다.
 */
export function resolveShift(s: Settings, now: number): Shift {
  const today = startOfLocalDay(now)
  const candidates = [
    buildShift(s, today - MS_PER_DAY),
    buildShift(s, today),
    buildShift(s, today + MS_PER_DAY),
  ]

  return candidates.reduce((best, c) => (distanceTo(c, now) < distanceTo(best, now) ? c : best))
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
