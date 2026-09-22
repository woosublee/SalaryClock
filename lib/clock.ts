import type { Shift } from '@/lib/shift'

const MS_PER_12H = 43_200_000

export interface HandAngles {
  hour: number
  minute: number
  second: number
}

export interface Arc {
  startDeg: number
  sweepDeg: number
}

/** 그 시각의 자정 이후 경과 밀리초. 로컬 시각 기준. */
function msIntoDay(now: number): number {
  const d = new Date(now)
  return (
    d.getHours() * 3_600_000 +
    d.getMinutes() * 60_000 +
    d.getSeconds() * 1000 +
    d.getMilliseconds()
  )
}

/**
 * 12시 방향 0도, 시계방향 증가.
 *
 * 밀리초를 버리지 않고 그대로 각도로 환산하는 것이 스위프 운동의 전부다.
 * Math.floor로 초를 끊으면 1초마다 6도씩 튀는 쿼츠 시계가 된다.
 */
export function handAngles(now: number): HandAngles {
  const t = msIntoDay(now)
  return {
    second: ((t % 60_000) / 60_000) * 360,
    minute: ((t % 3_600_000) / 3_600_000) * 360,
    hour: ((t % MS_PER_12H) / MS_PER_12H) * 360,
  }
}

/** 그 시각의 12시간 문자판 위치 (0~360). */
export function dialAngle(now: number): number {
  return ((msIntoDay(now) % MS_PER_12H) / MS_PER_12H) * 360
}

/** 두 시각 사이를 문자판 호로. 12시간을 넘으면 360도로 자른다. */
export function arcBetween(fromMs: number, toMs: number): Arc {
  const span = Math.max(0, toMs - fromMs)
  return {
    startDeg: dialAngle(fromMs),
    sweepDeg: Math.min(360, (span / MS_PER_12H) * 360),
  }
}

export function polarPoint(cx: number, cy: number, r: number, deg: number) {
  const rad = ((deg - 90) * Math.PI) / 180
  return { x: cx + r * Math.cos(rad), y: cy + r * Math.sin(rad) }
}

export function arcPath(cx: number, cy: number, r: number, arc: Arc): string {
  if (arc.sweepDeg <= 0) return ''
  // 정확히 360도는 시작점과 끝점이 같아 SVG가 아무것도 그리지 않는다. 살짝 줄인다.
  const sweep = Math.min(arc.sweepDeg, 359.99)
  const start = polarPoint(cx, cy, r, arc.startDeg)
  const end = polarPoint(cx, cy, r, arc.startDeg + sweep)
  const largeArc = sweep > 180 ? 1 : 0
  return `M ${start.x} ${start.y} A ${r} ${r} 0 ${largeArc} 1 ${end.x} ${end.y}`
}

const EMPTY_ARC: Arc = { startDeg: 0, sweepDeg: 0 }

/**
 * 시프트를 문자판 위의 호 셋으로.
 *
 * 휴무일에는 시프트가 없다(null). 빈 호를 돌려주면 arcPath가 빈 d를 만들어
 * 얼굴들이 아무것도 그리지 않는다 — 얼굴마다 분기를 넣을 필요가 없다.
 */
export function shiftArcs(shift: Shift | null, now: number) {
  if (shift === null) {
    return { work: EMPTY_ARC, progress: EMPTY_ARC, lunch: null }
  }

  const clampedNow = Math.min(Math.max(now, shift.startMs), shift.endMs)
  return {
    work: arcBetween(shift.startMs, shift.endMs),
    progress: arcBetween(shift.startMs, clampedNow),
    lunch:
      shift.lunchStartMs !== null && shift.lunchEndMs !== null
        ? arcBetween(shift.lunchStartMs, shift.lunchEndMs)
        : null,
  }
}

/**
 * 문자판 위의 각도가 호 안에 드는지.
 * 눈금 하나하나를 진행 여부로 칠할 때 쓴다.
 */
export function angleInArc(deg: number, arc: Arc): boolean {
  if (arc.sweepDeg <= 0) return false
  const rel = (((deg - arc.startDeg) % 360) + 360) % 360
  return rel <= Math.min(arc.sweepDeg, 360)
}

/**
 * 호를 부채꼴로 닫은 path. 중심에서 뻗어나간 면적으로 진행을 보여줄 때 쓴다.
 * 길이가 0이면 빈 문자열을 돌려준다 — SVG가 빈 d를 그리지 않게.
 */
export function sectorPath(cx: number, cy: number, r: number, arc: Arc): string {
  if (arc.sweepDeg <= 0) return ''
  const sweep = Math.min(arc.sweepDeg, 359.99)
  const start = polarPoint(cx, cy, r, arc.startDeg)
  const end = polarPoint(cx, cy, r, arc.startDeg + sweep)
  const largeArc = sweep > 180 ? 1 : 0
  return `M ${cx} ${cy} L ${start.x} ${start.y} A ${r} ${r} 0 ${largeArc} 1 ${end.x} ${end.y} Z`
}
