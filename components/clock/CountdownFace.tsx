'use client'

import { handAngles, arcBetween, arcPath, shiftArcs, polarPoint } from '@/lib/clock'
import { CX, CY, faceA11y, type ClockFaceProps } from './types'

const RING_R = 92
const DIAL_R = 74

/**
 * 남은 — 다른 페이스들이 "얼마나 쌓였나"를 그린다면, 이건 "얼마나 남았나"를 그린다.
 *
 * 호가 차오르는 게 아니라 퇴근 쪽으로 줄어든다. 같은 시간을 반대편에서 보는
 * 것뿐인데 하루의 체감이 완전히 달라져서 페이스 하나를 따로 뒀다.
 * 색도 쌓임(에메랄드)과 구분해 호박색을 쓴다.
 */
export function CountdownFace({ now, shift, className, label }: ClockFaceProps) {
  const hands = handAngles(now)
  const arcs = shiftArcs(shift, now)

  const remaining =
    shift === null
      ? { startDeg: 0, sweepDeg: 0 }
      : arcBetween(Math.min(Math.max(now, shift.startMs), shift.endMs), shift.endMs)

  return (
    <svg viewBox="0 0 200 200" className={className} {...faceA11y(label)}>
      {/* 지나간 구간은 흔적만 */}
      <path
        d={arcPath(CX, CY, RING_R, arcs.work)}
        fill="none"
        stroke="currentColor"
        strokeWidth={2}
        className="text-slate-200 dark:text-slate-800"
      />
      {/* 남은 구간 */}
      <path
        d={arcPath(CX, CY, RING_R, remaining)}
        fill="none"
        stroke="currentColor"
        strokeWidth={7}
        strokeLinecap="round"
        className="text-amber-500"
      />
      {/* 남은 구간 안의 점심은 파낸다 */}
      {arcs.lunch && (
        <path
          d={arcPath(CX, CY, RING_R, arcs.lunch)}
          fill="none"
          stroke="currentColor"
          strokeWidth={11}
          className="text-white dark:text-slate-950"
        />
      )}

      {/* 퇴근 지점 표식. 근무가 없는 날은 arcs.work가 0이라 12시 자리에 점이
          찍히므로, 남은 페이스들과 마찬가지로 shift가 없으면 아예 그리지 않는다. */}
      {shift !== null &&
        (() => {
          const p = polarPoint(CX, CY, RING_R, arcs.work.startDeg + arcs.work.sweepDeg)
          return <circle cx={p.x} cy={p.y} r={4} className="fill-amber-600 dark:fill-amber-400" />
        })()}

      {Array.from({ length: 12 }, (_, i) => {
        const outer = polarPoint(CX, CY, DIAL_R, i * 30)
        const inner = polarPoint(CX, CY, DIAL_R - (i % 3 === 0 ? 10 : 4), i * 30)
        return (
          <line
            key={i}
            x1={outer.x}
            y1={outer.y}
            x2={inner.x}
            y2={inner.y}
            stroke="currentColor"
            strokeWidth={i % 3 === 0 ? 2.5 : 1}
            strokeLinecap="round"
            className="text-slate-300 dark:text-slate-600"
          />
        )
      })}

      <g className="text-slate-800 dark:text-slate-100">
        <line
          x1={CX}
          y1={CY + 9}
          x2={CX}
          y2={CY - 40}
          stroke="currentColor"
          strokeWidth={5}
          strokeLinecap="round"
          transform={`rotate(${hands.hour} ${CX} ${CY})`}
        />
        <line
          x1={CX}
          y1={CY + 11}
          x2={CX}
          y2={CY - 60}
          stroke="currentColor"
          strokeWidth={3}
          strokeLinecap="round"
          transform={`rotate(${hands.minute} ${CX} ${CY})`}
        />
      </g>
      <line
        x1={CX}
        y1={CY + 14}
        x2={CX}
        y2={CY - 66}
        stroke="currentColor"
        strokeWidth={1.25}
        strokeLinecap="round"
        className="text-amber-500"
        transform={`rotate(${hands.second} ${CX} ${CY})`}
      />
      <circle cx={CX} cy={CY} r={3.5} className="fill-amber-500" />
    </svg>
  )
}
