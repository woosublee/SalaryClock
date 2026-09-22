'use client'

import { monthCells, type DayKind } from '@/lib/calendar'

interface Props {
  year: number
  /** 0-based */
  month: number
  overrides: readonly string[]
  onToggle: (date: string) => void
  onClearMonth: () => void
}

const DOW_LABELS = ['일', '월', '화', '수', '목', '금', '토'] as const

const KIND_CLASS: Record<DayKind, string> = {
  work: 'text-slate-700 hover:bg-slate-100 dark:text-slate-200 dark:hover:bg-slate-700',
  weekend: 'bg-slate-100 text-slate-400 dark:bg-slate-800 dark:text-slate-500',
  holiday: 'bg-rose-50 text-rose-400 dark:bg-rose-950/40 dark:text-rose-400',
  'custom-off': 'bg-slate-300 font-medium text-slate-600 dark:bg-slate-600 dark:text-slate-200',
  'custom-work': 'bg-emerald-100 font-medium text-emerald-700 dark:bg-emerald-900/50 dark:text-emerald-300',
}

export function MonthCalendar({ year, month, overrides, onToggle, onClearMonth }: Props) {
  const cells = monthCells(year, month, overrides)
  const workdays = cells.filter((c) => c.isWorkday).length

  // 1일이 무슨 요일인지에 맞춰 앞을 비운다
  const leading = cells[0].dow

  return (
    <div className="mt-2 rounded-lg bg-slate-50 p-3 dark:bg-slate-800/60">
      <div className="flex items-baseline justify-between">
        <span className="text-xs font-medium text-slate-600 dark:text-slate-300">
          {year}년 {month + 1}월 · 근무 {workdays}일
        </span>
        <button
          type="button"
          onClick={onClearMonth}
          className="text-xs text-slate-400 underline underline-offset-2 hover:text-slate-600 dark:hover:text-slate-300"
        >
          이 달 선택 지우기
        </button>
      </div>

      <div className="mt-2 grid grid-cols-7 gap-1">
        {DOW_LABELS.map((label, i) => (
          <div
            key={label}
            className={`py-1 text-center text-[0.625rem] ${
              i === 0 ? 'text-rose-400' : i === 6 ? 'text-sky-400' : 'text-slate-400'
            }`}
          >
            {label}
          </div>
        ))}

        {Array.from({ length: leading }, (_, i) => (
          <div key={`pad-${i}`} />
        ))}

        {cells.map((cell) => (
          <button
            key={cell.date}
            type="button"
            onClick={() => onToggle(cell.date)}
            aria-pressed={!cell.isWorkday}
            aria-label={`${month + 1}월 ${cell.day}일 ${cell.isWorkday ? '근무' : '휴무'}`}
            className={`aspect-square rounded text-xs tabular-nums transition-colors ${KIND_CLASS[cell.kind]}`}
          >
            {cell.day}
          </button>
        ))}
      </div>

      <div className="mt-2 flex flex-wrap gap-x-3 gap-y-1 text-[0.625rem] text-slate-400 dark:text-slate-500">
        <span className="flex items-center gap-1">
          <span className="size-2 rounded-sm bg-slate-100 dark:bg-slate-800" />
          주말
        </span>
        <span className="flex items-center gap-1">
          <span className="size-2 rounded-sm bg-rose-50 dark:bg-rose-950/40" />
          공휴일
        </span>
        <span className="flex items-center gap-1">
          <span className="size-2 rounded-sm bg-slate-300 dark:bg-slate-600" />
          내가 쉰 날
        </span>
        <span className="flex items-center gap-1">
          <span className="size-2 rounded-sm bg-emerald-100 dark:bg-emerald-900/50" />
          쉬는날 출근
        </span>
      </div>
    </div>
  )
}
