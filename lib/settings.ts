import { z } from 'zod'
import { isValidHHmm, parseHHmm, durationMinutes } from '@/lib/time'

export type PayMode = 'annual' | 'monthly' | 'hourly'
export type WorkDaysMode = 'auto' | 'calendar' | 'manual'
export type ThemeMode = 'light' | 'dark'
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
  /** 금액을 가렸을 때 보이는 디지털 시각을 12시간제(오전/오후)로 쓸지 */
  hour12: boolean
  /**
   * 저장된 값이 없을 때만 기기 설정에서 가져온다(loadSettings 참고).
   * 한 번 저장된 뒤로는 기기 설정이 바뀌어도 사용자가 고른 값을 지킨다.
   */
  theme: ThemeMode
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
  hour12: false,
  theme: 'light',
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
    hour12: z.boolean(),
    theme: z.enum(['light', 'dark']),
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

/** 기기의 다크모드 설정. 못 읽으면 밝은 쪽으로 본다 */
export function deviceTheme(): ThemeMode {
  try {
    return window.matchMedia?.('(prefers-color-scheme: dark)')?.matches ? 'dark' : 'light'
  } catch {
    return 'light'
  }
}

/**
 * 저장값이 없을 때의 설정. 기본값에 기기 테마를 심는다 — 저장값이 깨졌거나
 * 초기화한 직후도 첫 방문과 같다. 기본값의 'light'를 그대로 쓰면 다크모드
 * 기기에서 초기화하는 순간 화면이 하얘진다.
 */
export function firstVisit(): Settings {
  return { ...DEFAULT_SETTINGS, theme: deviceTheme() }
}

export function loadSettings(): { settings: Settings; hasStored: boolean } {
  if (typeof window === 'undefined') {
    return { settings: DEFAULT_SETTINGS, hasStored: false }
  }
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY)
    // 첫 방문에는 기기 설정을 그대로 가져온다. 사용자가 토글을 누르는 순간부터
    // 저장된 값이 기준이 된다.
    if (!raw) return { settings: firstVisit(), hasStored: false }
    const stored: unknown = JSON.parse(raw)
    if (typeof stored !== 'object' || stored === null || Array.isArray(stored)) {
      return { settings: firstVisit(), hasStored: false }
    }
    // 스키마에 필드가 늘어도 예전에 저장한 값은 살린다. 없는 필드만 기본값으로
    // 채우고, 있는 필드는 여전히 검증한다. 테마는 첫 방문과 같이 기기 설정에서
    // 가져온다. 키를 올리거나(v2→v3) 통째로 버리면 사용자가 찍어 둔 연봉과
    // 달력이 한꺼번에 날아간다.
    const parsed = SettingsSchema.safeParse({
      ...DEFAULT_SETTINGS,
      theme: deviceTheme(),
      ...stored,
    })
    if (!parsed.success) return { settings: firstVisit(), hasStored: false }
    return { settings: parsed.data, hasStored: true }
  } catch {
    return { settings: firstVisit(), hasStored: false }
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
