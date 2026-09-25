'use client'

import { handAngles, sectorPath, shiftArcs, polarPoint } from '@/lib/clock'
import { CX, CY, faceA11y, type ClockFaceProps } from './types'

const R = 88

/**
 * 채움 — 진행을 선이 아니라 면적으로 읽는다.
 *
 * 링은 굵기가 일정해서 "얼마나 왔나"가 각도로만 읽히는데, 부채꼴은 화면에서
 * 차지하는 넓이로 읽힌다. 하루가 차오르는 걸 몸으로 느끼게 하는 쪽이다.
 * 점심 구간은 바탕색으로 파내서 파이에 홈이 생긴다.
 */
export function SectorFace({ now, shift, className, label }: ClockFaceProps) {
  const hands = handAngles(now)
  const arcs = shiftArcs(shift, now)

  return (
    <svg viewBox="0 0 200 200" className={className} {...faceA11y(label)}>
      <circle cx={CX} cy={CY} r={R} className="fill-slate-50 dark:fill-slate-900" />

      {/* 근무 구간 전체 */}
      <path d={sectorPath(CX, CY, R, arcs.work)} className="fill-slate-200/70 dark:fill-slate-800" />
      {/* 지나간 만큼 */}
      <path d={sectorPath(CX, CY, R, arcs.progress)} className="fill-emerald-400/70 dark:fill-emerald-600/50" />
      {/* 점심은 파낸다 */}
      {arcs.lunch && (
        <path d={sectorPath(CX, CY, R, arcs.lunch)} className="fill-white dark:fill-slate-950" />
      )}

      <circle
        cx={CX}
        cy={CY}
        r={R}
        fill="none"
        stroke="currentColor"
        strokeWidth={1.5}
        className="text-slate-300 dark:text-slate-700"
      />

      {/* 정시 눈금만 아주 짧게. 면적이 주인공이라 문자판은 물러선다 */}
      {Array.from({ length: 12 }, (_, i) => {
        const outer = polarPoint(CX, CY, R, i * 30)
        const inner = polarPoint(CX, CY, R - (i % 3 === 0 ? 9 : 4), i * 30)
        return (
          <line
            key={i}
            x1={outer.x}
            y1={outer.y}
            x2={inner.x}
            y2={inner.y}
            stroke="currentColor"
            strokeWidth={i % 3 === 0 ? 2 : 1}
            className="text-slate-400 dark:text-slate-600"
          />
        )
      })}

      <g className="text-slate-800 dark:text-slate-100">
        <line
          x1={CX}
          y1={CY}
          x2={CX}
          y2={CY - 44}
          stroke="currentColor"
          strokeWidth={4}
          strokeLinecap="round"
          transform={`rotate(${hands.hour} ${CX} ${CY})`}
        />
        <line
          x1={CX}
          y1={CY}
          x2={CX}
          y2={CY - 66}
          stroke="currentColor"
          strokeWidth={2.5}
          strokeLinecap="round"
          transform={`rotate(${hands.minute} ${CX} ${CY})`}
        />
      </g>
      <line
        x1={CX}
        y1={CY}
        x2={CX}
        y2={CY - 78}
        stroke="currentColor"
        strokeWidth={1}
        strokeLinecap="round"
        className="text-emerald-700 dark:text-emerald-300"
        transform={`rotate(${hands.second} ${CX} ${CY})`}
      />
      <circle cx={CX} cy={CY} r={3} className="fill-slate-800 dark:fill-slate-100" />
    </svg>
  )
}
