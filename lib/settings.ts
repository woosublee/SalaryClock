import { z } from 'zod'
import { isValidHHmm, parseHHmm, durationMinutes } from '@/lib/time'

export type PayMode = 'annual' | 'monthly' | 'hourly'
export type WorkDaysMode = 'auto' | 'calendar' | 'manual'
export type ClockStyle =
  | 'minimal'
  | 'numerals'
  | 'grain'
  | 'rings'
  | 'sector'
  | 'dots'
  | 'countdown'
  | 'level'
  | 'sundial'
  | 'pulse'

export interface Settings {
  payMode: PayMode
  payAmount: number
  /**
   * auto     — 평일에서 공휴일을 뺀 수
   * calendar — 달력에서 직접 고른 수 (dayOverrides 반영)
   * manual   — workDaysPerMonth를 그대로
   */
  workDaysMode: WorkDaysMode
  workDaysPerMonth: number
  /**
   * 기본값(주말·공휴일)을 뒤집은 날짜들. 'YYYY-MM-DD'.
   * 연차를 더하는 것과 공휴일에 출근한 것을 같은 목록에 담는다.
   */
  dayOverrides: string[]
  workStart: string
  workEnd: string
  lunchEnabled: boolean
  /** 점심 시작 시각 */
  lunchStart: string
  /**
   * 점심 중 무급으로 처리할 시간(분).
   * 자리를 두 시간 비워도 회사 기준 무급이 한 시간이면 60을 넣으면 된다.
   */
  lunchMinutes: number
  /** 실수령액 기준으로 보여줄지 */
  netPay: boolean
  /** 공제율을 직접 지정한 경우 0..1. null이면 자동 추정 */
  deductionRate: number | null
  /** 시계 페이스 */
  clockStyle: ClockStyle
  /** 금액을 블러로 가릴지. 옆자리에서 화면이 보일 때 쓴다 */
  hideAmount: boolean
}

export const STORAGE_KEY = 'salaryclock.settings.v2'

export const DEFAULT_SETTINGS: Settings = {
  payMode: 'annual',
  payAmount: 40_000_000,
  workDaysMode: 'auto',
  workDaysPerMonth: 21,
  dayOverrides: [],
  workStart: '09:00',
  workEnd: '18:00',
  lunchEnabled: true,
  lunchStart: '12:00',
  lunchMinutes: 60,
  netPay: false,
  deductionRate: null,
  clockStyle: 'minimal',
  hideAmount: false,
}

const hhmm = z.string().refine(isValidHHmm, { message: 'HH:mm 형식이어야 합니다' })

export const SettingsSchema = z
  .object({
    payMode: z.enum(['annual', 'monthly', 'hourly']),
    payAmount: z
      .number({ error: '급여 금액을 입력해 주세요' })
      .finite('급여 금액을 입력해 주세요')
      .positive('급여 금액은 0보다 커야 합니다'),
    workDaysMode: z.enum(['auto', 'calendar', 'manual']),
    workDaysPerMonth: z
      .number({ error: '근무일수를 입력해 주세요' })
      .finite('근무일수를 입력해 주세요')
      .positive('근무일수는 0보다 커야 합니다')
      .max(31, '근무일수는 31일을 넘을 수 없습니다'),
    dayOverrides: z
      .array(z.string().regex(/^\d{4}-\d{2}-\d{2}$/, '날짜 형식이 올바르지 않습니다'))
      .max(732, '지정한 날짜가 너무 많습니다'),
    workStart: hhmm,
    workEnd: hhmm,
    lunchEnabled: z.boolean(),
    lunchStart: hhmm,
    lunchMinutes: z
      .number({ error: '무급 시간을 입력해 주세요' })
      .finite('무급 시간을 입력해 주세요')
      .nonnegative('무급 시간은 0분 이상이어야 합니다')
      .max(1440, '무급 시간이 하루를 넘을 수 없습니다'),
    netPay: z.boolean(),
    deductionRate: z
      .number()
      .finite()
      .min(0, '공제율은 0% 이상이어야 합니다')
      .max(0.9, '공제율은 90%를 넘을 수 없습니다')
      .nullable(),
    clockStyle: z.enum([
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
    ]),
    hideAmount: z.boolean(),
  })
  .superRefine((s, ctx) => {
    // zod 4는 필드 검증이 실패해도 이 훅을 실행한다. 형식이 깨진 값을 파싱하면
    // parseHHmm이 throw 하므로, 아래 검사는 형식이 모두 성립할 때만 의미가 있다.
    if (!isValidHHmm(s.workStart) || !isValidHHmm(s.workEnd)) return
    if (s.lunchEnabled && !isValidHHmm(s.lunchStart)) return

    const shiftMin = durationMinutes(parseHHmm(s.workStart), parseHHmm(s.workEnd))
    if (shiftMin === 0) {
      ctx.addIssue({
        code: 'custom',
        path: ['workEnd'],
        message: '출근 시각과 퇴근 시각이 같을 수 없습니다',
      })
      return
    }
    if (!s.lunchEnabled) return

    if (s.lunchMinutes === 0) {
      ctx.addIssue({
        code: 'custom',
        path: ['lunchMinutes'],
        message: '무급 시간이 0분이면 점심시간 제외를 꺼주세요',
      })
      return
    }
    if (s.lunchMinutes >= shiftMin) {
      ctx.addIssue({
        code: 'custom',
        path: ['lunchMinutes'],
        message: '무급 시간이 근무시간 전체를 덮을 수 없습니다',
      })
      return
    }

    // 근무 시작을 원점으로 옮긴 상대 좌표. 야간근무에서도 그대로 성립한다.
    const lunchOffset = durationMinutes(parseHHmm(s.workStart), parseHHmm(s.lunchStart))
    if (lunchOffset + s.lunchMinutes > shiftMin) {
      ctx.addIssue({
        code: 'custom',
        path: ['lunchStart'],
        message: '점심시간이 퇴근 시각을 넘어갑니다',
      })
    }
  })

export function loadSettings(): { settings: Settings; hasStored: boolean } {
  if (typeof window === 'undefined') {
    return { settings: DEFAULT_SETTINGS, hasStored: false }
  }
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY)
    if (!raw) return { settings: DEFAULT_SETTINGS, hasStored: false }
    const parsed = SettingsSchema.safeParse(JSON.parse(raw))
    if (!parsed.success) return { settings: DEFAULT_SETTINGS, hasStored: false }
    return { settings: parsed.data, hasStored: true }
  } catch {
    return { settings: DEFAULT_SETTINGS, hasStored: false }
  }
}

export function saveSettings(s: Settings): void {
  if (typeof window === 'undefined') return
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(s))
  } catch {
    // 사파리 프라이빗 모드 등 저장이 막힌 환경. 앱은 계속 돌아야 한다.
  }
}

export function clearSettings(): void {
  if (typeof window === 'undefined') return
  try {
    window.localStorage.removeItem(STORAGE_KEY)
  } catch {
    // 저장이 막힌 환경. 무시해도 메모리 상태는 기본값으로 돌아간다.
  }
}
