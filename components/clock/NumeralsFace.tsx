'use client'

import { handAngles, arcPath, shiftArcs, polarPoint } from '@/lib/clock'
import { CX, CY, faceA11y, type ClockFaceProps } from './types'

const NUM_R = 74
const ARC_R = 54

/**
 * 숫자판 — 역 대합실 시계.
 *
 * 빨간 초침 하나만 색을 쓰고 나머지는 전부 먹색이다. 그래서 진행 호도
 * 색이 아니라 굵기와 농도로 구분한다. 호를 숫자 안쪽에 둬서 시간을 읽는
 * 동선과 진행을 읽는 동선을 겹치지 않게 했다.
 */
export function NumeralsFace({ now, shift, className, label }: ClockFaceProps) {
  const hands = handAngles(now)
  const arcs = shiftArcs(shift, now)

  return (
    <svg viewBox="0 0 200 200" className={className} {...faceA11y(label)}>
      <circle
        cx={CX}
        cy={CY}
        r={94}
        fill="none"
        stroke="currentColor"
        strokeWidth={2}
        className="text-slate-300 dark:text-slate-600"
      />

      {/* 분 눈금 */}
      {Array.from({ length: 60 }, (_, i) => {
        if (i % 5 === 0) return null
        const outer = polarPoint(CX, CY, 90, i * 6)
        const inner = polarPoint(CX, CY, 86, i * 6)
        return (
          <line
            key={i}
            x1={outer.x}
            y1={outer.y}
            x2={inner.x}
            y2={inner.y}
            stroke="currentColor"
            strokeWidth={1}
            className="text-slate-300 dark:text-slate-600"
          />
        )
      })}

      {/* 1~12 */}
      {Array.from({ length: 12 }, (_, i) => {
        const hour = i === 0 ? 12 : i
        const p = polarPoint(CX, CY, NUM_R, i * 30)
        return (
          <text
            key={hour}
            x={p.x}
            y={p.y}
            textAnchor="middle"
            dominantBaseline="central"
            fontSize={17}
            fontFamily="Georgia, 'Times New Roman', serif"
            className="fill-slate-700 dark:fill-slate-200"
          >
            {hour}
          </text>
        )
      })}

      <path
        d={arcPath(CX, CY, ARC_R, arcs.work)}
        fill="none"
        stroke="currentColor"
        strokeWidth={3}
        className="text-slate-200 dark:text-slate-700"
      />
      <path
        d={arcPath(CX, CY, ARC_R, arcs.progress)}
        fill="none"
        stroke="currentColor"
        strokeWidth={3}
        className="text-slate-500 dark:text-slate-300"
      />
      {arcs.lunch && (
        <path
          d={arcPath(CX, CY, ARC_R, arcs.lunch)}
          fill="none"
          stroke="currentColor"
          strokeWidth={5}
          className="text-white dark:text-slate-950"
        />
      )}

      {/* 각진 바늘. 끝을 자르지 않아야 대합실 시계처럼 읽힌다 */}
      <g className="text-slate-800 dark:text-slate-100">
        <rect
          x={CX - 3}
          y={CY - 40}
          width={6}
          height={50}
          className="fill-current"
          transform={`rotate(${hands.hour} ${CX} ${CY})`}
        />
        <rect
          x={CX - 2}
          y={CY - 62}
          width={4}
          height={72}
          className="fill-current"
          transform={`rotate(${hands.minute} ${CX} ${CY})`}
        />
      </g>
      <g className="text-rose-600 dark:text-rose-500" transform={`rotate(${hands.second} ${CX} ${CY})`}>
        <rect x={CX - 0.75} y={CY - 70} width={1.5} height={88} className="fill-current" />
        <circle cx={CX} cy={CY - 58} r={5} fill="none" stroke="currentColor" strokeWidth={1.5} />
      </g>
      <circle cx={CX} cy={CY} r={4} className="fill-slate-800 dark:fill-slate-100" />
    </svg>
  )
}
