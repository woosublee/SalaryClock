/**
 * 맥 앱이 읽을 기대값을 웹 구현에서 뽑는다.
 *
 * 규칙의 단일 출처는 lib/다. 이 파일은 "Swift가 lib/와 같은 답을 내는가"를
 * 물을 재료를 만들 뿐, 정확성을 정의하지 않는다. 정확성은 각 모듈의
 * 유닛 테스트가 본다.
 *
 * 실행: npm run golden
 */
import { writeFileSync, mkdirSync } from 'node:fs'
import path from 'node:path'
import { DEFAULT_SETTINGS, type Settings } from '@/lib/settings'
import { computeEarnings } from '@/lib/salary'
import { resolveShift } from '@/lib/shift'
import { estimateDeductions } from '@/lib/deductions'
import { effectiveWorkDays } from '@/lib/workdays'
import { isDayOff } from '@/lib/calendar'

/** [year, month(0-based), day, hour, minute, second] */
type Clock = [number, number, number, number, number, number]

const ms = (c: Clock) => new Date(c[0], c[1], c[2], c[3], c[4], c[5], 0).getTime()

/**
 * 시각은 epoch ms가 아니라 로컬 시각 배열로 적는다. 양쪽 구현이 각자의
 * 타임존에서 다시 만들어야 하므로, ms를 박으면 KST 밖에서 전부 깨진다.
 */
const clock = (t: number): Clock => {
  const d = new Date(t)
  return [d.getFullYear(), d.getMonth(), d.getDate(), d.getHours(), d.getMinutes(), d.getSeconds()]
}

const clockOrNull = (t: number | null): Clock | null => (t === null ? null : clock(t))

const night: Settings = {
  ...DEFAULT_SETTINGS,
  workStart: '22:00',
  workEnd: '06:00',
  lunchStart: '01:00',
  lunchMinutes: 60,
}
const hourly: Settings = { ...DEFAULT_SETTINGS, payMode: 'hourly', payAmount: 12_000 }
const monthly: Settings = { ...DEFAULT_SETTINGS, payMode: 'monthly', payAmount: 3_000_000 }
const net: Settings = { ...DEFAULT_SETTINGS, netPay: true }
const offToday: Settings = { ...DEFAULT_SETTINGS, dayOverrides: ['2026-09-22'] }
const workOnHoliday: Settings = { ...DEFAULT_SETTINGS, dayOverrides: ['2026-09-24'] }

const SETTINGS: Record<string, Settings> = {
  default: DEFAULT_SETTINGS,
  night,
  hourly,
  monthly,
  net,
  offToday,
  workOnHoliday,
}

/** 경계만 촘촘히 깐다. 가운데 값은 규칙이 갈라져도 잘 안 드러난다. */
const MOMENTS: { label: string; settings: string; at: Clock }[] = [
  { label: '출근 1초 전', settings: 'default', at: [2026, 8, 22, 8, 59, 59] },
  { label: '출근 정각', settings: 'default', at: [2026, 8, 22, 9, 0, 0] },
  { label: '점심 직전', settings: 'default', at: [2026, 8, 22, 11, 59, 59] },
  { label: '점심 정각', settings: 'default', at: [2026, 8, 22, 12, 0, 0] },
  { label: '점심 종료 정각', settings: 'default', at: [2026, 8, 22, 13, 0, 0] },
  { label: '퇴근 1초 전', settings: 'default', at: [2026, 8, 22, 17, 59, 59] },
  { label: '퇴근 정각', settings: 'default', at: [2026, 8, 22, 18, 0, 0] },
  { label: '퇴근 직후', settings: 'default', at: [2026, 8, 22, 18, 0, 1] },
  { label: '자정 1초 전', settings: 'default', at: [2026, 8, 22, 23, 59, 59] },
  { label: '자정 직후', settings: 'default', at: [2026, 8, 23, 0, 0, 1] },
  { label: '새벽 00:30', settings: 'default', at: [2026, 8, 23, 0, 30, 0] },
  { label: '토요일 한낮', settings: 'default', at: [2026, 8, 26, 14, 0, 0] },
  { label: '일요일 한낮', settings: 'default', at: [2026, 8, 27, 14, 0, 0] },
  { label: '추석 연휴 한낮', settings: 'default', at: [2026, 8, 24, 14, 0, 0] },
  { label: '월말 근무 중', settings: 'default', at: [2026, 8, 30, 14, 0, 0] },
  { label: '공휴일 표 없는 해', settings: 'default', at: [2028, 8, 22, 14, 0, 0] },
  { label: '야간근무 자정 넘김', settings: 'night', at: [2026, 8, 23, 3, 0, 0] },
  { label: '야간근무 종료 후 아침', settings: 'night', at: [2026, 8, 23, 7, 0, 0] },
  { label: '야간근무가 공휴일 새벽으로 넘어감', settings: 'night', at: [2026, 8, 24, 3, 0, 0] },
  { label: '공휴일에 시작한 야간근무', settings: 'night', at: [2026, 8, 25, 3, 0, 0] },
  { label: '시급제 근무 중', settings: 'hourly', at: [2026, 8, 22, 14, 0, 0] },
  { label: '월급제 근무 중', settings: 'monthly', at: [2026, 8, 22, 14, 0, 0] },
  { label: '실수령 기준 근무 중', settings: 'net', at: [2026, 8, 22, 14, 0, 0] },
  { label: 'override로 쉬는 평일', settings: 'offToday', at: [2026, 8, 22, 14, 0, 0] },
  { label: 'override로 출근한 공휴일', settings: 'workOnHoliday', at: [2026, 8, 24, 14, 0, 0] },
]

const earnings = MOMENTS.map((m) => {
  const s = SETTINGS[m.settings]
  const e = computeEarnings(s, ms(m.at))
  return {
    label: m.label,
    settings: m.settings,
    at: m.at,
    expected: {
      phase: e.phase,
      earned: e.earned,
      perSecond: e.perSecond,
      progress: e.progress,
      elapsedPaidMs: e.elapsedPaidMs,
      totalPaidMs: e.totalPaidMs,
      msUntilStart: e.msUntilStart,
      msUntilEnd: e.msUntilEnd,
      msUntilLunchEnd: e.msUntilLunchEnd,
      remainingAmount: e.remainingAmount,
      dailyTotal: e.dailyTotal,
      workDays: e.workDays,
      deductionRate: e.deductionRate,
      hasShift: e.shift !== null,
    },
  }
})

const shifts = MOMENTS.map((m) => {
  const sh = resolveShift(SETTINGS[m.settings], ms(m.at))
  return {
    label: m.label,
    settings: m.settings,
    at: m.at,
    expected: {
      start: clock(sh.startMs),
      end: clock(sh.endMs),
      lunchStart: clockOrNull(sh.lunchStartMs),
      lunchEnd: clockOrNull(sh.lunchEndMs),
      // 길이는 시각이 아니라 기간이므로 ms 그대로 둔다.
      paidMs: sh.paidMs,
    },
  }
})

const GROSSES = [1_500_000, 2_000_000, 3_000_000, 3_500_000, 5_000_000, 6_000_000, 10_000_000]

const deductions = GROSSES.map((gross) => {
  const d = estimateDeductions(gross)
  return { gross, expected: d }
})

const DAYS: Clock[] = [
  [2026, 8, 22, 12, 0, 0],
  [2026, 8, 24, 12, 0, 0],
  [2026, 8, 26, 12, 0, 0],
  [2026, 8, 27, 12, 0, 0],
  [2026, 0, 1, 12, 0, 0],
  [2026, 1, 17, 12, 0, 0],
  [2028, 8, 22, 12, 0, 0],
]

const workdays = DAYS.map((at) => ({
  at,
  expected: {
    autoWorkDays: effectiveWorkDays(DEFAULT_SETTINGS, ms(at)),
    isDayOff: isDayOff([], ms(at)),
    isDayOffWithOverride: isDayOff(['2026-09-22', '2026-09-24'], ms(at)),
  },
}))

const outDir = path.resolve(import.meta.dirname, '..', 'shared', 'golden')
mkdirSync(outDir, { recursive: true })

const write = (name: string, data: unknown) => {
  writeFileSync(path.join(outDir, name), `${JSON.stringify(data, null, 2)}\n`, 'utf8')
  console.log(`wrote shared/golden/${name}`)
}

write('settings.json', SETTINGS)
write('earnings.json', earnings)
write('shift.json', shifts)
write('deductions.json', deductions)
write('workdays.json', workdays)
