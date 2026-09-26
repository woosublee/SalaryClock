'use client'

import type { Earnings } from '@/lib/salary'
import { formatClockTime, formatDuration } from '@/lib/format'

/**
 * 금액을 가렸을 때 금액 자리에 들어간다.
 *
 * 블러로 뭉개는 대신 아예 다른 걸 보여준다. 뭉갠 숫자는 "여기 가린 금액이
 * 있다"고 광고하는 셈이라 옆자리에서 오히려 더 눈에 띈다. 그냥 시계로
 * 보이는 편이 낫다.
 *
 * 행 구성과 글자 크기를 EarningsDisplay와 똑같이 맞춰 뒀다. 가리기를 켜고 끌 때
 * 시계가 위아래로 움직이지 않으려면 두 블록의 높이가 같아야 한다.
 */
export function TimeDisplay({
  now,
  earnings,
  hour12,
}: {
  now: number
  earnings: Earnings
  hour12: boolean
}) {
  // 문구 없이 숫자만 둔다. "퇴근까지"라고 써 붙이면 가린 티가 난다.
  const remainingMs = (() => {
    switch (earnings.phase) {
      case 'before':
        return earnings.msUntilStart
      case 'lunch':
        return earnings.msUntilLunchEnd
      case 'working':
        return earnings.msUntilEnd
      case 'after':
        return null
      case 'dayoff':
        return null
    }
  })()

  // 오전/오후를 숫자와 같은 크기로 쓰면 좁은 화면에서 한 줄을 넘는다.
  // 작게 떼어 붙이고 큰 숫자는 24시간제와 같은 폭을 유지한다.
  const [meridiem, hms] = (() => {
    const text = formatClockTime(now, hour12)
    const i = text.indexOf(' ')
    return i < 0 ? [null, text] : [text.slice(0, i), text.slice(i + 1)]
  })()

  return (
    <div className="text-center">
      {/* EarningsDisplay의 라벨+배지 줄과 높이를 맞추는 빈 줄 */}
      <p className="text-sm">{' '}</p>

      <p className="mt-1.5 font-mono text-5xl font-bold tabular-nums tracking-tight sm:text-6xl">
        {meridiem && (
          <span className="mr-1.5 align-baseline font-sans text-lg font-semibold tracking-normal text-slate-500 sm:text-xl dark:text-slate-400">
            {meridiem}
          </span>
        )}
        {hms}
      </p>

      <p className="mt-2 font-mono text-sm tabular-nums text-slate-500 dark:text-slate-400">
        {remainingMs === null ? ' ' : formatDuration(remainingMs)}
      </p>
    </div>
  )
}
