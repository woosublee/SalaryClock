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
 *      단, 오늘 출근할 시프트가 더 가까우면 그쪽에 넘긴다 (출근 전)
 *   3. 그 외                              → 오늘 시작할 시프트 (출근 전 — 0원)
 *
 * 2단계가 없으면 퇴근 직후 19:00에 아무것도 안 걸려 적립액이 0으로 리셋된다.
 * 여기서 두 힘이 맞선다.
 *
 * 하나는 "자정에 초기화"다. 예전 규칙은 "시간적으로 가장 가까운 시프트"였는데,
 * 00:30에는 어제 18:00 퇴근이 오늘 09:00 출근보다 가까워서 자정을 넘겨도 어제
 * 총액이 그대로 남았다. 2단계의 "오늘 안에 끝났는가"가 이걸 막는다 — 어제
 * 퇴근은 오늘 자정보다 앞이라 애초에 후보가 아니다.
 *
 * 다른 하나는 "출근 전 카운트다운"이다. 야간근무(22:00–06:00)는 어제 시프트가
 * 오늘 06:00에 끝나므로 "오늘 안에 끝났는가"만으로는 21:59까지 그게 계속
 * 걸린다. 그러면 출근 1분 전에도 `출근까지`가 안 뜨고 어제 총액이 남는다.
 * 그래서 2단계 안에서만 근접성을 다시 꺼낸다: 끝난 시프트와 오늘 출근 중
 * 가까운 쪽을 고르고, 같으면 끝난 쪽을 남긴다(방금 번 돈을 먼저 지우지 않는다).
 *
 * 근접성을 2단계 안에 가두는 것이 핵심이다. 어제 퇴근은 후보가 아니므로 자정
 * 초기화는 그대로 살아 있고, 자정을 넘는 시프트만 두 시각의 중간점에서 넘어간다.
 * 주간근무는 끝난 시프트가 곧 오늘 시프트라 비교 자체가 일어나지 않는다.
 */
export function resolveShift(s: Settings, now: number): Shift {
  const today = startOfLocalDay(now)
  const yesterday = buildShift(s, today - MS_PER_DAY)
  const todayShift = buildShift(s, today)
  // DST로 하루가 25시간인 날에는 today + MS_PER_DAY가 다음 자정보다 앞이라
  // now가 이 시프트에 걸릴 수 있다. 고정 오프셋 지역에서만 죽은 후보다.
  const tomorrow = buildShift(s, today + MS_PER_DAY)

  for (const c of [yesterday, todayShift, tomorrow]) {
    if (contains(c, now)) return c
  }

  // 둘 중 최대 하나만 걸린다. yesterday가 걸리려면 시프트가 자정을 넘어야 하고
  // todayShift가 걸리려면 넘지 않아야 해서, 둘이 동시에 참일 수 없다.
  const ended = [yesterday, todayShift].find((c) => c.endMs <= now && c.endMs > today)
  if (!ended) return todayShift

  // 오늘 출근이 아직 남았는가. ended가 todayShift면 now는 그 종료 이후이므로
  // 여기는 자정을 넘는 시프트(ended === yesterday)에서만 null이 아니다.
  const upcoming = now < todayShift.startMs ? todayShift : null
  if (!upcoming) return ended

  return now - ended.endMs <= upcoming.startMs - now ? ended : todayShift
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
