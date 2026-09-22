'use client'

import type { Earnings } from '@/lib/salary'
import { formatWon, formatDuration } from '@/lib/format'

interface Props {
  earnings: Earnings
  /**
   * 금액을 가린 상태. 내용은 TimeDisplay가 대신 보여주므로 여기서는 비우되,
   * 줄 높이는 그대로 차지해야 위쪽 시계가 움직이지 않는다.
   */
  hidden: boolean
}

export function StatusLine({ earnings, hidden }: Props) {
  const primary = (() => {
    switch (earnings.phase) {
      case 'before':
        return `출근까지 ${formatDuration(earnings.msUntilStart)}`
      case 'lunch':
        return `점심시간 · 재개까지 ${formatDuration(earnings.msUntilLunchEnd)}`
      case 'after':
        return '오늘 근무 종료'
      case 'working':
        return `퇴근까지 ${formatDuration(earnings.msUntilEnd)}`
    }
  })()

  const showRemaining = earnings.phase !== 'after'

  if (hidden) {
    return <p className="text-center font-mono text-sm tabular-nums">{' '}</p>
  }

  return (
    <p className="text-center font-mono text-sm tabular-nums text-slate-600 dark:text-slate-300">
      {primary}
      {showRemaining && (
        <span className="text-slate-400 dark:text-slate-500">
          {' · 남은 '}
          {formatWon(earnings.remainingAmount)}
        </span>
      )}
    </p>
  )
}
