'use client'

import { useId } from 'react'
import { handAngles } from '@/lib/clock'
import { paidMsBetween } from '@/lib/shift'
import { CX, CY, faceA11y, type ClockFaceProps } from './types'

const R = 88

/**
 * 수위 — 하루가 물처럼 차오른다.
 *
 * 다른 페이스는 진행을 테두리에서 말하는데, 이건 문자판 한가운데를 채운다.
 * 출근이 바닥, 퇴근이 천장이다. 점심시간에는 수면이 그대로 멈춘다 —
 * 돈이 안 쌓이는 시간을 따로 표시할 필요 없이 저절로 드러난다.
 *
 * 물결은 장식이 아니라 살아 있다는 신호다. 4초에 한 번 위상이 도는데,
 * 초침과 주기를 어긋나게 둬서 둘이 맞물려 보이지 않게 했다.
 */
export function LevelFace({ now, shift, className, label }: ClockFaceProps) {
  const hands = handAngles(now)
  const id = useId()
  const clipId = `level-clip-${id}`

  const progress =
    shift === null || shift.paidMs === 0
      ? 0
      : paidMsBetween(shift, shift.startMs, now) / shift.paidMs

  // 수면 높이. 진행 0이면 바닥, 1이면 천장.
  const surfaceY = CY + R - 2 * R * progress
  const phase = ((now % 4000) / 4000) * Math.PI * 2

  const steps = 28
  const points: string[] = []
  for (let i = 0; i <= steps; i += 1) {
    const x = CX - R + (2 * R * i) / steps
    const y = surfaceY + Math.sin(phase + (i / steps) * Math.PI * 4) * 2.5
    points.push(`${x.toFixed(2)} ${y.toFixed(2)}`)
  }
  const waterPath = `M ${points[0]} L ${points.slice(1).join(' L ')} L ${CX + R} ${CY + R} L ${CX - R} ${CY + R} Z`

  return (
    <svg viewBox="0 0 200 200" className={className} {...faceA11y(label)}>
      <defs>
        <clipPath id={clipId}>
          <circle cx={CX} cy={CY} r={R} />
        </clipPath>
      </defs>

      <circle cx={CX} cy={CY} r={R} className="fill-slate-50 dark:fill-slate-900" />

      <g clipPath={`url(#${clipId})`}>
        <path d={waterPath} className="fill-emerald-400/45 dark:fill-emerald-600/40" />
        {/* 수면선 하나만 진하게. 물이 어디까지 찼는지가 이 페이스의 전부다 */}
        <polyline
          points={points.join(' ')}
          fill="none"
          stroke="currentColor"
          strokeWidth={1.5}
          className="text-emerald-600 dark:text-emerald-400"
        />
      </g>

      <circle
        cx={CX}
        cy={CY}
        r={R}
        fill="none"
        stroke="currentColor"
        strokeWidth={1.5}
        className="text-slate-300 dark:text-slate-700"
      />

      {/* 바늘은 물 위에 뜬다. 수면과 겹쳐도 읽히도록 테두리를 덧그린다 */}
      <g transform={`rotate(${hands.hour} ${CX} ${CY})`}>
        <line
          x1={CX}
          y1={CY + 8}
          x2={CX}
          y2={CY - 42}
          stroke="currentColor"
          strokeWidth={7}
          strokeLinecap="round"
          className="text-white dark:text-slate-950"
        />
        <line
          x1={CX}
          y1={CY + 8}
          x2={CX}
          y2={CY - 42}
          stroke="currentColor"
          strokeWidth={4}
          strokeLinecap="round"
          className="text-slate-800 dark:text-slate-100"
        />
      </g>
      <g transform={`rotate(${hands.minute} ${CX} ${CY})`}>
        <line
          x1={CX}
          y1={CY + 10}
          x2={CX}
          y2={CY - 64}
          stroke="currentColor"
          strokeWidth={5}
          strokeLinecap="round"
          className="text-white dark:text-slate-950"
        />
        <line
          x1={CX}
          y1={CY + 10}
          x2={CX}
          y2={CY - 64}
          stroke="currentColor"
          strokeWidth={2.5}
          strokeLinecap="round"
          className="text-slate-800 dark:text-slate-100"
        />
      </g>
      <line
        x1={CX}
        y1={CY + 12}
        x2={CX}
        y2={CY - 72}
        stroke="currentColor"
        strokeWidth={1.25}
        strokeLinecap="round"
        className="text-slate-500 dark:text-slate-400"
        transform={`rotate(${hands.second} ${CX} ${CY})`}
      />
      <circle cx={CX} cy={CY} r={3} className="fill-slate-800 dark:fill-slate-100" />
    </svg>
  )
}
