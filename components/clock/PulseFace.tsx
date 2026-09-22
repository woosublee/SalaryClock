'use client'

import { handAngles, arcPath, shiftArcs } from '@/lib/clock'
import { CX, CY, type ClockFaceProps } from './types'

const RING_R = 92
const MAX_RIPPLE = 80
const RIPPLE_COUNT = 3

/**
 * 파문 — 초마다 중심에서 물결이 퍼진다.
 *
 * 돈이 한 방울씩 떨어져 번지는 모습이다. 이 앱이 가진 구조라서 가능한 얼굴이기도
 * 하다: 파문의 반지름은 애니메이션이 아니라 현재 시각의 소수점 부분으로 매 프레임
 * 계산된다. CSS 애니메이션이었다면 탭을 다시 열 때 시계와 어긋났을 것이다.
 *
 * 파문 셋을 1/3씩 어긋나게 띄워서 끊기지 않고 계속 번지게 했다.
 */
export function PulseFace({ now, shift, className }: ClockFaceProps) {
  const hands = handAngles(now)
  const arcs = shiftArcs(shift, now)

  const fraction = (now % 1000) / 1000

  return (
    <svg viewBox="0 0 200 200" className={className} role="img" aria-label="현재 시각과 근무 진행률">
      <path
        d={arcPath(CX, CY, RING_R, arcs.work)}
        fill="none"
        stroke="currentColor"
        strokeWidth={4}
        className="text-slate-200 dark:text-slate-800"
      />
      <path
        d={arcPath(CX, CY, RING_R, arcs.progress)}
        fill="none"
        stroke="currentColor"
        strokeWidth={4}
        strokeLinecap="round"
        className="text-sky-500"
      />

      {/* 퍼지는 파문. 멀어질수록 옅어진다 */}
      {Array.from({ length: RIPPLE_COUNT }, (_, i) => {
        const phase = (fraction + i / RIPPLE_COUNT) % 1
        return (
          <circle
            key={i}
            cx={CX}
            cy={CY}
            r={phase * MAX_RIPPLE}
            fill="none"
            stroke="currentColor"
            strokeWidth={1.5}
            strokeOpacity={(1 - phase) * 0.7}
            className="text-sky-400"
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
          strokeWidth={4}
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
      <circle cx={CX} cy={CY} r={4} className="fill-sky-500" />
    </svg>
  )
}
