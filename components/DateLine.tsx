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
  /**
   * 금액을 가린 상태. 근무시간·근무일수는 급여를 역산할 실마리이므로
   * 같이 내린다. 남는 건 날짜뿐이라 그만큼 크게 보여준다.
   */
  minimal: boolean
}

export function DateLine({
  now,
  workDays,
  monthInfo,
  isAutoWorkDays,
  workStart,
  workEnd,
  paidHours,
  minimal,
}: Props) {
  /*
   * 두 상태의 높이를 같게 잡는다. 일반 상태는 text-sm(1.25rem) + mt-0.5(0.125rem)
   * + text-xs(1rem) = 2.375rem이고, 가린 상태의 text-xl은 1.75rem이다.
   * 그대로 두면 가리기를 누를 때 아래 시계가 통째로 밀린다.
   */
  const BOX = 'flex h-[2.375rem] flex-col items-center justify-center text-center'

  if (minimal) {
    return (
      <div className={BOX}>
        <p className="text-3xl font-bold tracking-tight text-slate-800 dark:text-slate-100">
          {formatDateKo(now)}
        </p>
      </div>
    )
  }

  const paidLabel = Number.isInteger(paidHours) ? `${paidHours}` : paidHours.toFixed(1)

  // 공휴일을 실제로 빼고 있을 때만 알려준다. 자동 계산이 아니거나 공휴일이
  // 없는 달이면 굳이 덧붙이지 않는다.
  const holidayNote =
    isAutoWorkDays && monthInfo.hasHolidayData && monthInfo.holidays > 0
      ? ` (공휴일 ${monthInfo.holidays}일 제외)`
      : ''

  return (
    <div className={BOX}>
      <p className="text-sm font-medium text-slate-700 dark:text-slate-200">{formatDateKo(now)}</p>
      <p className="mt-0.5 text-xs text-slate-500 dark:text-slate-400">
        {workStart}–{workEnd} · 유급 {paidLabel}시간 · 이번 달 {workDays}일{holidayNote}
      </p>
    </div>
  )
}
