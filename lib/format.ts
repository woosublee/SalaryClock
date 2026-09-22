const wonFormatters = new Map<number, Intl.NumberFormat>()

function wonFormatter(fractionDigits: number): Intl.NumberFormat {
  let f = wonFormatters.get(fractionDigits)
  if (!f) {
    f = new Intl.NumberFormat('ko-KR', {
      style: 'currency',
      currency: 'KRW',
      minimumFractionDigits: fractionDigits,
      maximumFractionDigits: fractionDigits,
    })
    wonFormatters.set(fractionDigits, f)
  }
  return f
}

/**
 * 금액 표시. 항상 내림한다.
 *
 * 반올림하면 아직 벌지 않은 1원이 화면에 먼저 뜬다. 적립 카운터에서는
 * 실제로 쌓인 것보다 많아 보이는 쪽이 덜 쌓인 쪽보다 나쁘다.
 */
export function formatWon(n: number, fractionDigits = 0): string {
  const scale = 10 ** fractionDigits
  return wonFormatter(fractionDigits).format(Math.floor(n * scale) / scale)
}

/** 초당 적립액. 작은 값에서 0으로 뭉개지지 않도록 소수 1자리를 남긴다. */
export function formatPerSecond(n: number): string {
  return n < 100 ? n.toFixed(1) : String(Math.round(n))
}

export function formatDuration(ms: number): string {
  const total = Math.max(0, Math.floor(ms / 1000))
  const h = Math.floor(total / 3600)
  const m = Math.floor((total % 3600) / 60)
  const s = total % 60
  const pad = (v: number) => String(v).padStart(2, '0')
  return `${pad(h)}:${pad(m)}:${pad(s)}`
}

/**
 * 금액을 억/만 단위로 끊어 읽어준다.
 * 입력창에 0을 몇 개 쳤는지 눈으로 확인하기 위한 보조 표시다.
 */
export function formatKoreanUnits(n: number): string {
  const v = Math.floor(Math.max(0, n))
  if (v === 0) return '0원'

  const eok = Math.floor(v / 100_000_000)
  const man = Math.floor((v % 100_000_000) / 10_000)
  const rest = v % 10_000

  const parts: string[] = []
  if (eok) parts.push(`${eok.toLocaleString('ko-KR')}억`)
  if (man) parts.push(`${man.toLocaleString('ko-KR')}만`)
  if (rest) parts.push(rest.toLocaleString('ko-KR'))

  return `${parts.join(' ')}원`
}

const WEEKDAYS = ['일', '월', '화', '수', '목', '금', '토'] as const

/** "2026년 9월 22일 (화)" */
export function formatDateKo(now: number): string {
  const d = new Date(now)
  return `${d.getFullYear()}년 ${d.getMonth() + 1}월 ${d.getDate()}일 (${WEEKDAYS[d.getDay()]})`
}
