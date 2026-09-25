'use client'

import { handAngles, shiftArcs, polarPoint, angleInArc } from '@/lib/clock'
import { CX, CY, faceA11y, type ClockFaceProps } from './types'

const TICK_OUTER = 92

/**
 * 결 — 60개 분 눈금이 문자판 전체를 이룬다.
 *
 * 다른 페이스는 진행을 링 하나로 그리는데, 여기서는 눈금 자체가 물든다.
 * 지나간 시간이 낱낱의 눈금으로 쌓여 보이는 게 이 페이스의 전부다.
 * 점심 구간 눈금은 비워서 "여기는 안 쌓인다"를 같은 언어로 말한다.
 */
export function GrainFace({ now, shift, className, label }: ClockFaceProps) {
  const hands = handAngles(now)
  const arcs = shiftArcs(shift, now)

  return (
    <svg viewBox="0 0 200 200" className={className} {...faceA11y(label)}>
      {Array.from({ length: 60 }, (_, i) => {
        const deg = i * 6
        const isHour = i % 5 === 0

        const inLunch = arcs.lunch ? angleInArc(deg, arcs.lunch) : false
        const inProgress = !inLunch && angleInArc(deg, arcs.progress)
        const inWork = !inLunch && angleInArc(deg, arcs.work)

        const length = isHour ? 14 : 7
        const width = isHour ? 3 : 1.5

        const tone = inProgress
          ? 'text-orange-500'
          : inLunch
            ? 'text-slate-200 dark:text-slate-800'
            : inWork
              ? 'text-slate-400 dark:text-slate-500'
              : 'text-slate-200 dark:text-slate-700'

        const outer = polarPoint(CX, CY, TICK_OUTER, deg)
        const inner = polarPoint(CX, CY, TICK_OUTER - length, deg)

        return (
          <line
            key={i}
            x1={outer.x}
            y1={outer.y}
            x2={inner.x}
            y2={inner.y}
            stroke="currentColor"
            strokeWidth={width}
            className={tone}
          />
        )
      })}

      <g className="text-slate-800 dark:text-slate-100">
        <rect
          x={CX - 2.5}
          y={CY - 46}
          width={5}
          height={52}
          rx={2.5}
          className="fill-current"
          transform={`rotate(${hands.hour} ${CX} ${CY})`}
        />
        <rect
          x={CX - 2}
          y={CY - 68}
          width={4}
          height={74}
          rx={2}
          className="fill-current"
          transform={`rotate(${hands.minute} ${CX} ${CY})`}
        />
      </g>

      <g className="text-orange-500" transform={`rotate(${hands.second} ${CX} ${CY})`}>
        <rect x={CX - 1} y={CY - 72} width={2} height={82} className="fill-current" />
        <circle cx={CX} cy={CY + 14} r={4} className="fill-current" />
      </g>
      <circle cx={CX} cy={CY} r={5} className="fill-slate-800 dark:fill-slate-100" />
      <circle cx={CX} cy={CY} r={2} className="fill-orange-500" />
    </svg>
  )
}
