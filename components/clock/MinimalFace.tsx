'use client'

import { handAngles, arcPath, shiftArcs, polarPoint } from '@/lib/clock'
import { CX, CY, faceA11y, type ClockFaceProps } from './types'

const RING_R = 92
const DIAL_R = 76

/**
 * 말끔 — 사무실 벽시계.
 * 문자판은 조용하게 두고, 하루 진행은 바깥 링 하나로만 말한다.
 */
export function MinimalFace({ now, shift, className, label }: ClockFaceProps) {
  const hands = handAngles(now)
  const arcs = shiftArcs(shift, now)

  return (
    <svg viewBox="0 0 200 200" className={className} {...faceA11y(label)}>
      <path
        d={arcPath(CX, CY, RING_R, arcs.work)}
        fill="none"
        stroke="currentColor"
        strokeWidth={5}
        strokeLinecap="round"
        className="text-slate-200 dark:text-slate-700"
      />
      <path
        d={arcPath(CX, CY, RING_R, arcs.progress)}
        fill="none"
        stroke="currentColor"
        strokeWidth={5}
        strokeLinecap="round"
        className="text-emerald-500"
      />

      {/* 점심 구간은 링에서 비워 "여기는 돈이 안 붙는다"를 보여준다 */}
      {arcs.lunch && (
        <>
          <path
            d={arcPath(CX, CY, RING_R, arcs.lunch)}
            fill="none"
            stroke="currentColor"
            strokeWidth={9}
            className="text-white dark:text-slate-950"
          />
          <path
            d={arcPath(CX, CY, RING_R, arcs.lunch)}
            fill="none"
            stroke="currentColor"
            strokeWidth={1.5}
            strokeDasharray="2 3"
            className="text-slate-300 dark:text-slate-600"
          />
        </>
      )}

      {Array.from({ length: 12 }, (_, i) => {
        const deg = i * 30
        const outer = polarPoint(CX, CY, DIAL_R, deg)
        const inner = polarPoint(CX, CY, DIAL_R - (i % 3 === 0 ? 11 : 5), deg)
        return (
          <line
            key={i}
            x1={outer.x}
            y1={outer.y}
            x2={inner.x}
            y2={inner.y}
            stroke="currentColor"
            strokeWidth={i % 3 === 0 ? 3 : 1.5}
            strokeLinecap="round"
            className="text-slate-400 dark:text-slate-500"
          />
        )
      })}

      <g className="text-slate-800 dark:text-slate-100">
        <line
          x1={CX}
          y1={CY + 10}
          x2={CX}
          y2={CY - 42}
          stroke="currentColor"
          strokeWidth={5}
          strokeLinecap="round"
          transform={`rotate(${hands.hour} ${CX} ${CY})`}
        />
        <line
          x1={CX}
          y1={CY + 12}
          x2={CX}
          y2={CY - 62}
          stroke="currentColor"
          strokeWidth={3}
          strokeLinecap="round"
          transform={`rotate(${hands.minute} ${CX} ${CY})`}
        />
      </g>
      <line
        x1={CX}
        y1={CY + 16}
        x2={CX}
        y2={CY - 68}
        stroke="currentColor"
        strokeWidth={1.5}
        strokeLinecap="round"
        className="text-emerald-500"
        transform={`rotate(${hands.second} ${CX} ${CY})`}
      />
      <circle cx={CX} cy={CY} r={3.5} className="fill-emerald-500" />
    </svg>
  )
}
