'use client'

import type { Earnings } from '@/lib/salary'
import { formatWon, formatDuration } from '@/lib/format'

interface Props {
  earnings: Earnings
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

  return (
    <p className="text-center font-mono text-sm tabular-nums text-slate-600 dark:text-slate-300">
      {primary}
      {earnings.phase !== 'after' && (
        <span className="text-slate-400 dark:text-slate-500">
          {' · 남은 '}
          {/* 시간은 가리지 않는다. 가려야 하는 건 금액뿐이다 */}
          <span
            className={`transition-[filter] duration-200 ${hidden ? 'blur-[0.35em] select-none' : ''}`}
          >
            {formatWon(earnings.remainingAmount)}
          </span>
        </span>
      )}
    </p>
  )
}
