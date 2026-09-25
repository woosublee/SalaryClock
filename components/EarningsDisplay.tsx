'use client'

import type { Earnings } from '@/lib/salary'
import { formatWon, formatPerSecond } from '@/lib/format'
import { Won } from '@/components/Won'

export function EarningsDisplay({ earnings }: { earnings: Earnings }) {
  return (
    <div className="text-center">
      {/*
        배지를 인라인으로 두면 베이스라인에 붙어서 글자보다 아래로 내려간다.
        flex + items-center로 광학 중심을 맞춘다.
      */}
      <div className="flex items-center justify-center gap-1.5">
        <span className="text-sm text-slate-500 dark:text-slate-400">오늘 벌어들인 금액</span>
        <span className="rounded px-1.5 py-1 text-xs leading-none text-slate-500 ring-1 ring-slate-200 dark:text-slate-400 dark:ring-slate-700">
          {earnings.isNet ? '실수령' : '세전'}
        </span>
      </div>

      {/*
        소수 1자리까지 보여준다. 정수만 쓰면 초당 5.8원일 때 0.17초마다 한 번씩
        또각또각 올라가는데, 한 자리를 더 두면 프레임마다 바뀌어 흐르듯 보인다.
        두 자리는 눈에 안 읽히는 잡음이라 한 자리에서 끊는다.
      */}
      <p className="mt-1.5 font-mono text-5xl font-bold tabular-nums tracking-tight sm:text-6xl">
        <Won text={formatWon(Math.floor(earnings.earned))} />
        <span className="text-slate-500 dark:text-slate-400">
          .{Math.floor((earnings.earned % 1) * 10)}
        </span>
      </p>

      <p className="mt-2 font-mono text-sm tabular-nums text-emerald-600 dark:text-emerald-400">
        {earnings.perSecond > 0 ? `+${formatPerSecond(earnings.perSecond)} / 초` : ' '}
      </p>
    </div>
  )
}
