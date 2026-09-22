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
import { isDayOff, monthCells, workdaysFromCalendar } from '@/lib/calendar'
import { afterWorkKind } from '@/lib/afterWork'
import {
  formatWon,
  formatPerSecond,
  formatDuration,
  formatClockTime,
  formatDateKo,
  formatKoreanUnits,
} from '@/lib/format'
import { handAngles, dialAngle, arcBetween } from '@/lib/clock'

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
// hourly는 netPay가 false라 monthlyGross까지 가지 않는다. 시급의 월 환산
// 분기를 실제로 지나가는 케이스가 하나는 있어야 한다.
const hourlyNet: Settings = { ...hourly, netPay: true }
const monthly: Settings = { ...DEFAULT_SETTINGS, payMode: 'monthly', payAmount: 3_000_000 }
const net: Settings = { ...DEFAULT_SETTINGS, netPay: true }
// 점심 끄기. 이게 없으면 점심을 늘 빼는 구현이 모든 케이스를 통과한다.
const noLunch: Settings = { ...DEFAULT_SETTINGS, lunchEnabled: false }
const offToday: Settings = { ...DEFAULT_SETTINGS, dayOverrides: ['2026-09-22'] }
const workOnHoliday: Settings = { ...DEFAULT_SETTINGS, dayOverrides: ['2026-09-24'] }
// 9/24(목)는 추석이라 그대로 쉬고 9/25(금)만 출근으로 뒤집는다 — afterWorkKind가
// restThisWeek(같은 주)를 내는 유일한 골든 케이스를 만들기 위한 설정이다.
const workFridayOfHolidayWeek: Settings = { ...DEFAULT_SETTINGS, dayOverrides: ['2026-09-25'] }
// 공제율을 직접 넣은 경우. 이게 없으면 deductionRateFor의 "사용자 값을 쓴다"
// 분기가 어느 골든에도 안 걸려서, 필드를 통째로 무시하고 늘 추정하는 구현도
// 전부 통과한다. 맥 설정 창에 공제율 칸이 생긴 뒤로는 실제 사용자 경로다.
const customRate: Settings = { ...net, deductionRate: 0.245 }
// calendar 모드 — 근무일수를 달력에서 센다. 평일 하나를 쉬고 주말 둘을 일해
// auto(평일 − 공휴일)와 숫자가 갈라지게 둔다. 그렇지 않으면 calendar 분기를
// auto로 구현해도 통과한다. 뒤집는 날은 아래 moment의 날짜(9/22)를 피한다 —
// 그날을 뒤집으면 근무일수가 아니라 phase가 달라져 무엇을 보는지 흐려진다.
const calendarMode: Settings = {
  ...DEFAULT_SETTINGS,
  workDaysMode: 'calendar',
  dayOverrides: ['2026-09-21', '2026-09-26', '2026-09-27'],
}
// manual 모드 — workDaysPerMonth를 그대로 쓴다. 기본값 21은 9월의 auto 값과
// 겹칠 수 있어 일부러 18로 어긋내 둔다.
const manualMode: Settings = {
  ...DEFAULT_SETTINGS,
  workDaysMode: 'manual',
  workDaysPerMonth: 18,
}

const SETTINGS: Record<string, Settings> = {
  default: DEFAULT_SETTINGS,
  night,
  hourly,
  hourlyNet,
  monthly,
  noLunch,
  net,
  offToday,
  workOnHoliday,
  workFridayOfHolidayWeek,
  customRate,
  calendarMode,
  manualMode,
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
  { label: '실수령 기준 시급제 근무 중', settings: 'hourlyNet', at: [2026, 8, 22, 14, 0, 0] },
  { label: '점심 없는 설정 — 근무 중', settings: 'noLunch', at: [2026, 8, 22, 14, 0, 0] },
  { label: '점심 없는 설정 — 점심 시간대', settings: 'noLunch', at: [2026, 8, 22, 12, 30, 0] },
  { label: '크리스마스(2026 연말 공휴일)', settings: 'default', at: [2026, 11, 25, 14, 0, 0] },
  { label: '설날 연휴(2027 공휴일 표)', settings: 'default', at: [2027, 1, 8, 14, 0, 0] },
  { label: '야간근무 연말 — 자정 전', settings: 'night', at: [2026, 11, 31, 23, 59, 59] },
  { label: '야간근무 연말 — 자정 직후', settings: 'night', at: [2027, 0, 1, 0, 0, 1] },
  { label: 'override로 쉬는 평일', settings: 'offToday', at: [2026, 8, 22, 14, 0, 0] },
  { label: 'override로 출근한 공휴일', settings: 'workOnHoliday', at: [2026, 8, 24, 14, 0, 0] },
  { label: '공제율 직접 입력 — 근무 중', settings: 'customRate', at: [2026, 8, 22, 14, 0, 0] },
  { label: '달력 모드 근무일수 — 근무 중', settings: 'calendarMode', at: [2026, 8, 22, 14, 0, 0] },
  { label: '수동 근무일수 — 근무 중', settings: 'manualMode', at: [2026, 8, 22, 14, 0, 0] },
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

/**
 * 양 끝을 넣어 연금 상·하한과 상위 세율 구간·세액공제 한도까지 닿게 한다.
 *
 * 경계값만이 아니라 "한 번도 안 들어가는 분기"가 없어야 한다. 각 값이 여는 분기:
 *   200_000     — 연금 하한(PENSION_FLOOR), 근로소득공제 1구간(연 500만 이하 ×0.7)
 *   20_000_000  — 누진세율 38% 구간 (과세표준 약 2.06억)
 *   50_000_000  — 누진세율 42% 구간 (과세표준 약 5.41억)
 *   100_000_000 — 누진세율 45% 구간 (과세표준 약 11.0억)
 * 나머지 값이 6·15·24·35·40% 구간과 근로소득공제 2~5구간, 세액공제 한도
 * 네 구간을 이미 덮는다.
 */
const GROSSES = [
  200_000, 500_000, 1_500_000, 2_000_000, 3_000_000, 3_500_000, 5_000_000, 6_000_000,
  10_000_000, 20_000_000, 30_000_000, 50_000_000, 100_000_000,
]

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
  [2026, 11, 25, 12, 0, 0],
  [2027, 1, 8, 12, 0, 0],
  [2028, 8, 22, 12, 0, 0],
]

/**
 * isDayOffWithOverride를 만든 override 목록. 파일에 같이 적어야 다른 언어가
 * 그 불리언을 재현할 수 있다. 여기서만 정의하고 테스트는 파일에서 읽는다.
 */
const WORKDAY_OVERRIDES = ['2026-09-22', '2026-09-24']

const workdays = {
  overrides: WORKDAY_OVERRIDES,
  cases: DAYS.map((at) => ({
    at,
    expected: {
      autoWorkDays: effectiveWorkDays(DEFAULT_SETTINGS, ms(at)),
      isDayOff: isDayOff([], ms(at)),
      isDayOffWithOverride: isDayOff(WORKDAY_OVERRIDES, ms(at)),
    },
  })),
}

/** 퇴근 후 격려 문구의 종류. 문구 자체가 아니라 kind만 고정한다 — lib/afterWork 참고. */
const AFTER_WORK_DAYS: { label: string; settings: string; at: Clock }[] = [
  { label: '화요일 퇴근', settings: 'default', at: [2026, 8, 22, 19, 0, 0] },
  { label: '수요일 퇴근 — 추석 연휴 직전', settings: 'default', at: [2026, 8, 23, 19, 0, 0] },
  { label: '금요일 퇴근', settings: 'default', at: [2026, 8, 25, 19, 0, 0] },
  { label: '목요일 퇴근', settings: 'default', at: [2026, 9, 1, 19, 0, 0] },
  { label: '연휴 직전 — 설 연휴', settings: 'default', at: [2026, 1, 13, 19, 0, 0] },
  { label: '공휴일을 출근으로 뒤집음', settings: 'workOnHoliday', at: [2026, 8, 23, 19, 0, 0] },
  { label: '야간근무 퇴근 후 아침', settings: 'night', at: [2026, 8, 23, 7, 0, 0] },
  {
    label: '추석 연휴 중 금요일만 출근 — 같은 주',
    settings: 'workFridayOfHolidayWeek',
    at: [2026, 8, 23, 19, 0, 0],
  },
]

const afterWork = AFTER_WORK_DAYS.map((m) => ({
  ...m,
  expected: afterWorkKind(SETTINGS[m.settings], ms(m.at)),
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

/** 달력 그리드가 그리는 날짜별 상태. 맥의 MonthCalendarView가 같은 칸을 칠해야 한다. */
const CALENDAR_MONTHS: { label: string; year: number; month: number; overrides: string[] }[] = [
  { label: '2026년 9월 — 추석이 평일에 걸린 달', year: 2026, month: 8, overrides: [] },
  { label: '2026년 9월 — 평일 하나를 쉬고 토요일 하나를 일함', year: 2026, month: 8,
    overrides: ['2026-09-22', '2026-09-26'] },
  { label: '2026년 2월 — 설 연휴', year: 2026, month: 1, overrides: [] },
  { label: '2027년 1월 — 다음 해 표', year: 2027, month: 0, overrides: [] },
  { label: '2028년 9월 — 공휴일 표가 없는 해', year: 2028, month: 8, overrides: [] },
]

const calendars = CALENDAR_MONTHS.map((m) => ({
  ...m,
  expected: {
    workdays: workdaysFromCalendar(m.year, m.month, m.overrides),
    cells: monthCells(m.year, m.month, m.overrides).map((c) => ({
      date: c.date, day: c.day, dow: c.dow, kind: c.kind, isWorkday: c.isWorkday,
    })),
  },
}))

write('calendar.json', calendars)
write('afterWork.json', afterWork)

/** 내림 규칙과 소수 자리 처리를 고정한다. 반올림하면 안 벌은 돈이 먼저 뜬다. */
const FORMAT_AMOUNTS = [0, 0.4, 0.9, 1, 999.99, 1234.56, 83412.49, 166666.66666666666, 1_0000_0000]

const formats = {
  won: FORMAT_AMOUNTS.map((n) => ({ n, expected: formatWon(n) })),
  wonOneDecimal: FORMAT_AMOUNTS.map((n) => ({ n, expected: formatWon(n, 1) })),
  perSecond: [0, 0.04, 5.79, 99.94, 99.96, 100, 1234.5].map((n) => ({
    n,
    expected: formatPerSecond(n),
  })),
  duration: [0, -1, 999, 1000, 59_000, 60_000, 3_599_000, 3_600_000, 32_401_000, 86_399_000].map(
    (ms) => ({ ms, expected: formatDuration(ms) }),
  ),
  koreanUnits: [0, 1, 9999, 10_000, 100_000_000, 123_456_789, 40_000_000].map((n) => ({
    n,
    expected: formatKoreanUnits(n),
  })),
  dateKo: MOMENTS.map((m) => ({ at: m.at, expected: formatDateKo(ms(m.at)) })),
  clockTime: MOMENTS.map((m) => ({ at: m.at, expected: formatClockTime(ms(m.at)) })),
}

/** 스위프 운동. 밀리초를 버리면 1초마다 6도씩 튀는 쿼츠 시계가 된다. */
const CLOCK_MOMENTS: [number, number, number, number, number, number, number][] = [
  [2026, 8, 22, 0, 0, 0, 0],
  [2026, 8, 22, 0, 0, 0, 500],
  [2026, 8, 22, 3, 0, 0, 0],
  [2026, 8, 22, 9, 30, 15, 250],
  [2026, 8, 22, 12, 0, 0, 0],
  [2026, 8, 22, 15, 45, 30, 750],
  [2026, 8, 22, 23, 59, 59, 999],
]

const clocks = {
  hands: CLOCK_MOMENTS.map((c) => {
    const t = new Date(c[0], c[1], c[2], c[3], c[4], c[5], c[6]).getTime()
    const h = handAngles(t)
    return { at: c, expected: { hour: h.hour, minute: h.minute, second: h.second } }
  }),
  dial: CLOCK_MOMENTS.map((c) => {
    const t = new Date(c[0], c[1], c[2], c[3], c[4], c[5], c[6]).getTime()
    return { at: c, expected: dialAngle(t) }
  }),
  arcs: MOMENTS.map((m) => {
    const sh = resolveShift(SETTINGS[m.settings], ms(m.at))
    const a = arcBetween(sh.startMs, sh.endMs)
    return {
      label: m.label,
      settings: m.settings,
      at: m.at,
      expected: { startDeg: a.startDeg, sweepDeg: a.sweepDeg },
    }
  }),
}

write('format.json', formats)
write('clock.json', clocks)
