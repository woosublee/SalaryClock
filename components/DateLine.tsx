'use client'

import { formatDateKo } from '@/lib/format'
import type { WorkdayInfo } from '@/lib/workdays'

interface Props {
  now: number
  workDays: number
  monthInfo: WorkdayInfo
  isAutoWorkDays: boolean
  workStart: string
  workEnd: string
  paidHours: number
}

export function DateLine({
  now,
  workDays,
  monthInfo,
  isAutoWorkDays,
  workStart,
  workEnd,
  paidHours,
}: Props) {
  const paidLabel = Number.isInteger(paidHours) ? `${paidHours}` : paidHours.toFixed(1)

  // 공휴일을 실제로 빼고 있을 때만 알려준다. 자동 계산이 아니거나 공휴일이
  // 없는 달이면 굳이 덧붙이지 않는다.
  const holidayNote =
    isAutoWorkDays && monthInfo.hasHolidayData && monthInfo.holidays > 0
      ? ` (공휴일 ${monthInfo.holidays}일 제외)`
      : ''

  return (
    <div className="text-center">
      <p className="text-sm font-medium text-slate-700 dark:text-slate-200">{formatDateKo(now)}</p>
      <p className="mt-0.5 text-xs text-slate-400 dark:text-slate-500">
        {workStart}–{workEnd} · 유급 {paidLabel}시간 · 이번 달 {workDays}일{holidayNote}
      </p>
    </div>
  )
}
