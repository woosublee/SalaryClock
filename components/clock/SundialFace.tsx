'use client'

import { useId } from 'react'
import { handAngles, arcPath, shiftArcs, polarPoint } from '@/lib/clock'
import { CX, CY, faceA11y, type ClockFaceProps } from './types'

const PLATE_R = 90
const SHADOW_LEN = 78

/**
 * 해시계 — 바늘 대신 그림자가 시각을 가리킨다.
 *
 * 아날로그 시계의 조상이고, 원래부터 "하루가 어디쯤 왔나"를 재는 물건이었다.
 * 그래서 이 앱과 주제가 맞는다.
 *
 * 그림자는 시침 각도의 반대편에 진다. 해시계에는 초가 없으므로 초침도 두지
 * 않고, 대신 테두리를 도는 작은 점 하나로만 살아 있다는 걸 알린다.
 * 분은 그림자 끝에 붙은 짧은 눈금이 맡는다.
 */
export function SundialFace({ now, shift, className, label }: ClockFaceProps) {
  const hands = handAngles(now)
  const arcs = shiftArcs(shift, now)
  // 미리보기와 본 시계가 동시에 뜨므로 그라디언트 id가 겹치면 안 된다
  const shadowId = `sundial-shadow-${useId()}`

  // 해는 시각의 반대편에 있다고 본다. 그림자는 해에서 멀어지는 쪽으로 뻗는다.
  const shadowDeg = hands.hour
  const secondDot = polarPoint(CX, CY, PLATE_R - 5, hands.second)
  const minuteTick = polarPoint(CX, CY, PLATE_R - 12, hands.minute)
  const minuteTickInner = polarPoint(CX, CY, PLATE_R - 20, hands.minute)

  return (
    <svg viewBox="0 0 200 200" className={className} {...faceA11y(label)}>
      {/* 석판 */}
      <circle cx={CX} cy={CY} r={PLATE_R} className="fill-stone-100 dark:fill-stone-900" />
      <circle
        cx={CX}
        cy={CY}
        r={PLATE_R}
        fill="none"
        stroke="currentColor"
        strokeWidth={1.5}
        className="text-stone-300 dark:text-stone-700"
      />

      {/* 석판에 새겨진 근무 구간 */}
      <path
        d={arcPath(CX, CY, PLATE_R - 8, arcs.work)}
        fill="none"
        stroke="currentColor"
        strokeWidth={4}
        className="text-stone-200 dark:text-stone-800"
      />
      <path
        d={arcPath(CX, CY, PLATE_R - 8, arcs.progress)}
        fill="none"
        stroke="currentColor"
        strokeWidth={4}
        strokeLinecap="round"
        className="text-amber-600/70 dark:text-amber-500/60"
      />

      {/* 시각선 */}
      {Array.from({ length: 12 }, (_, i) => {
        const outer = polarPoint(CX, CY, PLATE_R - 16, i * 30)
        const inner = polarPoint(CX, CY, PLATE_R - (i % 3 === 0 ? 30 : 24), i * 30)
        return (
          <line
            key={i}
            x1={outer.x}
            y1={outer.y}
            x2={inner.x}
            y2={inner.y}
            stroke="currentColor"
            strokeWidth={i % 3 === 0 ? 2 : 1}
            className="text-stone-400 dark:text-stone-600"
          />
        )
      })}

      {/* 그림자. 끝으로 갈수록 가늘어지고 옅어진다 */}
      <defs>
        <linearGradient id={shadowId} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="currentColor" stopOpacity="0.55" />
          <stop offset="100%" stopColor="currentColor" stopOpacity="0.12" />
        </linearGradient>
      </defs>
      <g className="text-stone-700 dark:text-stone-300" transform={`rotate(${shadowDeg} ${CX} ${CY})`}>
        <path
          d={`M ${CX - 7} ${CY} L ${CX + 7} ${CY} L ${CX + 2} ${CY - SHADOW_LEN} L ${CX - 2} ${CY - SHADOW_LEN} Z`}
          fill={`url(#${shadowId})`}
        />
      </g>

      {/* 분 눈금 */}
      <line
        x1={minuteTick.x}
        y1={minuteTick.y}
        x2={minuteTickInner.x}
        y2={minuteTickInner.y}
        stroke="currentColor"
        strokeWidth={2.5}
        strokeLinecap="round"
        className="text-stone-600 dark:text-stone-300"
      />

      {/* 노몬 — 그림자를 만드는 막대 */}
      <circle cx={CX} cy={CY} r={7} className="fill-stone-300 dark:fill-stone-700" />
      <circle cx={CX} cy={CY} r={3.5} className="fill-stone-600 dark:fill-stone-300" />

      {/* 초는 테두리를 도는 점 하나로만 */}
      <circle cx={secondDot.x} cy={secondDot.y} r={2} className="fill-amber-600 dark:fill-amber-400" />
    </svg>
  )
}
