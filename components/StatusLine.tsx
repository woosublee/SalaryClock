'use client'

import type { Earnings } from '@/lib/salary'
import { formatWon, formatDuration } from '@/lib/format'
import { Won } from '@/components/Won'
import { afterWorkKind, type AfterWorkKind } from '@/lib/afterWork'
import type { Settings } from '@/lib/settings'

interface Props {
  earnings: Earnings
  settings: Settings
  now: number
  /**
   * 금액을 가린 상태. 내용은 TimeDisplay가 대신 보여주므로 여기서는 비우되,
   * 줄 높이는 그대로 차지해야 위쪽 시계가 움직이지 않는다.
   */
  hidden: boolean
}

/**
 * 퇴근 후 격려 문구. 종류(kind)는 lib/afterWork가 정하고, 실제 한국어
 * 문장은 여기(UI)가 갖는다 — 맥 PopoverView.swift도 같은 표를 따른다.
 */
/**
 * 퇴근 뒤 상태줄 문구.
 *
 * 앞에 이모지를 하나 둔다. 이 줄만 숫자가 없어서(다른 상태는 남은 시간이나
 * 금액이 흐른다) 글자만 있으면 화면이 멈춘 것처럼 보인다.
 *
 * 종류(kind)는 lib/afterWork.ts가 정하고 문구는 화면이 갖는다 — 맥 앱의
 * PopoverView도 같은 표를 따른다.
 */
const AFTER_WORK_TEXT: Record<AfterWorkKind, string> = {
  tomorrow: '🌙 오늘 하루도 수고하셨어요',
  restThisWeek: '😌 오늘은 여기까지, 편히 쉬세요',
  nextWeek: '🎉 한 주 동안 수고하셨어요',
  longBreak: '🏖️ 즐거운 연휴 보내세요',
}

export function StatusLine({ earnings, settings, now, hidden }: Props) {
  const primary = (() => {
    switch (earnings.phase) {
      case 'before':
        return `출근까지 ${formatDuration(earnings.msUntilStart)}`
      case 'lunch':
        return `점심시간 ${formatDuration(earnings.msUntilLunchEnd)}`
      case 'after':
        return AFTER_WORK_TEXT[afterWorkKind(settings, now)]
      case 'working':
        return `퇴근까지 ${formatDuration(earnings.msUntilEnd)}`
      case 'dayoff':
        return ''
    }
  })()

  // 휴무일에는 남은 금액이 0이라 '· 남은 ₩0'만 남는다. 지금은 페이지가 늘
  // hidden으로 그려서 안 보이지만, 여기서도 빼 둔다.
  const showRemaining = earnings.phase !== 'after' && earnings.phase !== 'dayoff'

  if (hidden) {
    return <p className="text-center font-mono text-sm tabular-nums">{' '}</p>
  }

  return (
    <p className="text-center font-mono text-sm tabular-nums text-slate-600 dark:text-slate-300">
      {primary}
      {showRemaining && (
        <span className="text-slate-400 dark:text-slate-500">
          {' · 남은 '}
          <Won text={formatWon(earnings.remainingAmount)} />
        </span>
      )}
    </p>
  )
}
