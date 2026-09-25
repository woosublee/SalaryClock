'use client'

import { handAngles, arcPath } from '@/lib/clock'
import { paidMsBetween } from '@/lib/shift'
import { CX, CY, faceA11y, type ClockFaceProps } from './types'

const R_PROGRESS = 92
const R_HOUR = 74
const R_MINUTE = 60
const R_SECOND = 46

/**
 * 고리 — 바늘이 없다.
 *
 * 다른 페이스는 문자판 위 위치로 시각을 읽지만, 여기서는 네 개의 호가
 * 각각 12시에서 출발해 자란 길이로 읽는다. 바깥이 하루 진행이고,
 * 안으로 들어올수록 시·분·초로 빨라진다. 초 고리가 1분마다 감겼다 풀리는
 * 게 이 페이스의 움직임 전부다.
 */
export function RingsFace({ now, shift, className, label }: ClockFaceProps) {
  const hands = handAngles(now)

  const progress =
    shift === null || shift.paidMs === 0
      ? 0
      : paidMsBetween(shift, shift.startMs, now) / shift.paidMs

  const ring = (key: string, r: number, sweepDeg: number, tone: string, width: number) => (
    <g key={key}>
      <circle
        cx={CX}
        cy={CY}
        r={r}
        fill="none"
        stroke="currentColor"
        strokeWidth={width}
        className="text-slate-100 dark:text-slate-800"
      />
      <path
        d={arcPath(CX, CY, r, { startDeg: 0, sweepDeg })}
        fill="none"
        stroke="currentColor"
        strokeWidth={width}
        strokeLinecap="round"
        className={tone}
      />
    </g>
  )

  return (
    <svg viewBox="0 0 200 200" className={className} {...faceA11y(label)}>
      {ring('progress', R_PROGRESS, progress * 360, 'text-emerald-500', 6)}
      {ring('hour', R_HOUR, hands.hour, 'text-slate-500 dark:text-slate-300', 4)}
      {ring('minute', R_MINUTE, hands.minute, 'text-slate-400', 3)}
      {ring('second', R_SECOND, hands.second, 'text-emerald-400', 2)}

      {/* 12시 기준선. 네 고리가 모두 여기서 출발한다는 걸 알려준다 */}
      <line
        x1={CX}
        y1={CY - R_PROGRESS - 4}
        x2={CX}
        y2={CY - R_SECOND + 4}
        stroke="currentColor"
        strokeWidth={0.75}
        className="text-slate-300 dark:text-slate-700"
      />
    </svg>
  )
}
