'use client'

import type { Earnings } from '@/lib/salary'
import { formatWon, formatPerSecond } from '@/lib/format'

interface Props {
  earnings: Earnings
  hidden: boolean
}

export function EarningsDisplay({ earnings, hidden }: Props) {
  // 블러는 시각 효과일 뿐이라 텍스트는 그대로 남는다. 화면을 가리는 용도이지
  // 개발자 도구를 막는 용도가 아니다. 선택까지 막아 실수로 드래그해 읽히는 건 방지한다.
  const veil = hidden ? 'blur-[0.35em] select-none' : ''

  return (
    <div className="text-center">
      {/*
        배지를 인라인으로 두면 베이스라인에 붙어서 글자보다 아래로 내려간다.
        flex + items-center로 광학 중심을 맞춘다.
      */}
      <div className="flex items-center justify-center gap-1.5">
        <span className="text-sm text-slate-500 dark:text-slate-400">오늘 벌어들인 금액</span>
        <span className="rounded px-1.5 py-1 text-xs leading-none text-slate-400 ring-1 ring-slate-200 dark:text-slate-500 dark:ring-slate-700">
          {earnings.isNet ? '실수령' : '세전'}
        </span>
      </div>

      {/*
        소수 1자리까지 보여준다. 정수만 쓰면 초당 5.8원일 때 0.17초마다 한 번씩
        또각또각 올라가는데, 한 자리를 더 두면 프레임마다 바뀌어 흐르듯 보인다.
        두 자리는 눈에 안 읽히는 잡음이라 한 자리에서 끊는다.
      */}
      <p
        className={`mt-1.5 font-mono text-5xl font-bold tabular-nums tracking-tight transition-[filter] duration-200 sm:text-6xl ${veil}`}
      >
        {formatWon(Math.floor(earnings.earned))}
        <span className="text-slate-400 dark:text-slate-500">
          .{Math.floor((earnings.earned % 1) * 10)}
        </span>
      </p>

      <p
        className={`mt-2 font-mono text-sm tabular-nums text-emerald-600 transition-[filter] duration-200 dark:text-emerald-400 ${veil}`}
      >
        {earnings.perSecond > 0 ? `+${formatPerSecond(earnings.perSecond)} / 초` : ' '}
      </p>
    </div>
  )
}
