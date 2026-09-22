export const MS_PER_MINUTE = 60_000
export const MS_PER_HOUR = 3_600_000
export const MS_PER_DAY = 86_400_000

const HHMM = /^([01]\d|2[0-3]):([0-5]\d)$/

export function isValidHHmm(v: string): boolean {
  return HHMM.test(v)
}

export function parseHHmm(v: string): number {
  const m = HHMM.exec(v)
  if (!m) throw new Error(`시각 형식이 올바르지 않습니다: ${v}`)
  return Number(m[1]) * 60 + Number(m[2])
}

export function formatHHmm(minutes: number): string {
  const m = ((minutes % 1440) + 1440) % 1440
  const hh = String(Math.floor(m / 60)).padStart(2, '0')
  const mm = String(m % 60).padStart(2, '0')
  return `${hh}:${mm}`
}

/** 자정을 넘는 구간에도 항상 0 이상을 돌려준다. 시작과 끝이 같으면 0. */
export function durationMinutes(startMin: number, endMin: number): number {
  return (((endMin - startMin) % 1440) + 1440) % 1440
}

export function startOfLocalDay(now: number): number {
  const d = new Date(now)
  d.setHours(0, 0, 0, 0)
  return d.getTime()
}
