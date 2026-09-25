'use client'

import { handAngles, shiftArcs, polarPoint, angleInArc } from '@/lib/clock'
import { CX, CY, faceA11y, type ClockFaceProps } from './types'

const DOT_R = 84

/**
 * 점 — 결(60눈금)과 같은 발상이지만 해상도를 12로 낮췄다.
 *
 * 눈금이 촘촘하면 진행이 연속된 띠로 보이고, 12개로 줄이면 "몇 시간 남았나"가
 * 셀 수 있는 덩어리로 보인다. 초침은 선이 아니라 궤도를 도는 작은 점이라
 * 문자판의 어휘를 그대로 쓴다.
 */
export function DotsFace({ now, shift, className, label }: ClockFaceProps) {
  const hands = handAngles(now)
  const arcs = shiftArcs(shift, now)
  const secondDot = polarPoint(CX, CY, DOT_R, hands.second)

  return (
    <svg viewBox="0 0 200 200" className={className} {...faceA11y(label)}>
      {Array.from({ length: 12 }, (_, i) => {
        const deg = i * 30
        const inLunch = arcs.lunch ? angleInArc(deg, arcs.lunch) : false
        const inProgress = !inLunch && angleInArc(deg, arcs.progress)
        const inWork = !inLunch && angleInArc(deg, arcs.work)
        const p = polarPoint(CX, CY, DOT_R, deg)

        if (inLunch) {
          return (
            <circle
              key={i}
              cx={p.x}
              cy={p.y}
              r={4}
              fill="none"
              stroke="currentColor"
              strokeWidth={1.25}
              className="text-slate-300 dark:text-slate-600"
            />
          )
        }

        return (
          <circle
            key={i}
            cx={p.x}
            cy={p.y}
            r={inProgress ? 5.5 : 3.5}
            className={
              inProgress
                ? 'fill-emerald-500'
                : inWork
                  ? 'fill-slate-300 dark:fill-slate-600'
                  : 'fill-slate-200 dark:fill-slate-800'
            }
          />
        )
      })}

      <g className="text-slate-800 dark:text-slate-100">
        <line
          x1={CX}
          y1={CY}
          x2={CX}
          y2={CY - 40}
          stroke="currentColor"
          strokeWidth={4.5}
          strokeLinecap="round"
          transform={`rotate(${hands.hour} ${CX} ${CY})`}
        />
        <line
          x1={CX}
          y1={CY}
          x2={CX}
          y2={CY - 62}
          stroke="currentColor"
          strokeWidth={2.5}
          strokeLinecap="round"
          transform={`rotate(${hands.minute} ${CX} ${CY})`}
        />
      </g>

      <circle cx={secondDot.x} cy={secondDot.y} r={2.5} className="fill-emerald-500" />
      <circle cx={CX} cy={CY} r={3} className="fill-slate-800 dark:fill-slate-100" />
    </svg>
  )
}
