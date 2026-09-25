'use client'

import { useCallback, useRef, useState } from 'react'
import type { ClockStyle } from '@/lib/settings'
import type { Shift } from '@/lib/shift'
import { AnalogClock, CLOCK_STYLE_LABELS } from '@/components/AnalogClock'

const STYLES: ClockStyle[] = [
  'minimal',
  'numerals',
  'grain',
  'rings',
  'sector',
  'dots',
  'countdown',
  'level',
  'sundial',
  'pulse',
]

interface Props {
  value: ClockStyle
  /** 미리보기에 쓸 시각. 패널이 열린 순간으로 고정된 값을 받는다 */
  now: number
  shift: Shift
  onChange: (style: ClockStyle) => void
}

/**
 * 이름만 나열하면 고를 수가 없다. 페이스를 실제로 그려서 보여준다.
 * 시각을 고정해서 받고, 부모(SettingsPanel)가 memo라 입력이 없는 동안에는
 * 미리보기들이 다시 그려지지 않는다.
 *
 * 페이스가 늘어나도 아래로 흐르지 않고 한 줄에서 좌우로 넘긴다. 설정 패널은
 * 위아래로 이미 길어서, 여기까지 세로로 쌓이면 다른 항목이 화면 밖으로 밀린다.
 */
export function ClockStylePicker({ value, now, shift, onChange }: Props) {
  const trackRef = useRef<HTMLDivElement | null>(null)
  const [atStart, setAtStart] = useState(true)
  const [atEnd, setAtEnd] = useState(true)

  const measure = useCallback((el: HTMLDivElement | null) => {
    if (!el) return
    // 1px 여유를 둔다. 브라우저가 소수점 스크롤을 반올림해서 끝에 닿아도
    // scrollLeft + clientWidth가 scrollWidth에 정확히 안 맞는 경우가 있다.
    setAtStart(el.scrollLeft <= 1)
    setAtEnd(el.scrollLeft + el.clientWidth >= el.scrollWidth - 1)
  }, [])

  // ref 콜백에서 재는 이유: 마운트 직후 폭을 알아야 오른쪽 버튼을 띄울지 정할 수
  // 있는데, useEffect에서 setState 하는 건 이 프로젝트 린트 규칙이 막는다.
  const attach = useCallback(
    (el: HTMLDivElement | null) => {
      trackRef.current = el
      measure(el)
    },
    [measure],
  )

  const page = (direction: 1 | -1) => {
    const el = trackRef.current
    if (!el) return
    el.scrollBy({ left: direction * el.clientWidth * 0.8, behavior: 'smooth' })
  }

  const arrow = (direction: 1 | -1, disabled: boolean) => (
    <button
      type="button"
      onClick={() => page(direction)}
      disabled={disabled}
      aria-label={direction === 1 ? '다음 시계' : '이전 시계'}
      className={`absolute top-1/2 z-10 -translate-y-1/2 rounded-full border border-slate-200 bg-white p-1 text-slate-500 shadow-sm transition-opacity dark:border-slate-600 dark:bg-slate-800 dark:text-slate-300 ${
        direction === 1 ? '-right-1' : '-left-1'
      } ${disabled ? 'pointer-events-none opacity-0' : 'opacity-100 hover:text-slate-800 dark:hover:text-slate-100'}`}
    >
      <svg
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth={2.5}
        strokeLinecap="round"
        strokeLinejoin="round"
        className="size-3.5"
        aria-hidden="true"
      >
        {direction === 1 ? <polyline points="9 6 15 12 9 18" /> : <polyline points="15 6 9 12 15 18" />}
      </svg>
    </button>
  )

  return (
    <div className="relative mt-1">
      {arrow(-1, atStart)}
      {arrow(1, atEnd)}

      <div
        ref={attach}
        onScroll={(e) => measure(e.currentTarget)}
        className="flex snap-x snap-mandatory gap-2 overflow-x-auto scroll-smooth [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
      >
        {STYLES.map((style) => {
          const selected = style === value
          return (
            <button
              key={style}
              type="button"
              onClick={() => onChange(style)}
              aria-pressed={selected}
              className={`flex w-[4.5rem] shrink-0 snap-start flex-col items-center gap-1 rounded-lg border p-2 transition-colors ${
                selected
                  ? 'border-emerald-500 bg-emerald-50 dark:bg-emerald-950/40'
                  : 'border-slate-200 hover:border-slate-300 dark:border-slate-700 dark:hover:border-slate-600'
              }`}
            >
              <AnalogClock now={now} shift={shift} style={style} className="h-12 w-12" />
              <span
                className={`whitespace-nowrap text-xs ${
                  selected
                    ? 'font-medium text-emerald-700 dark:text-emerald-300'
                    : 'text-slate-500 dark:text-slate-400'
                }`}
              >
                {CLOCK_STYLE_LABELS[style]}
              </span>
            </button>
          )
        })}
      </div>
    </div>
  )
}
