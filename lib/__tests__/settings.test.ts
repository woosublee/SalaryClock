import { describe, it, expect } from 'vitest'
import { SettingsSchema, DEFAULT_SETTINGS, type Settings } from '@/lib/settings'

function withOverrides(o: Partial<Settings>): Settings {
  return { ...DEFAULT_SETTINGS, ...o }
}

describe('DEFAULT_SETTINGS', () => {
  it('9 to 6, 점심 1시간이 기본이다', () => {
    expect(DEFAULT_SETTINGS).toEqual({
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
      theme: 'light',
    })
  })

  it('스스로 유효하다', () => {
    expect(SettingsSchema.safeParse(DEFAULT_SETTINGS).success).toBe(true)
  })
})

describe('SettingsSchema', () => {
  it('시급 모드를 통과시킨다', () => {
    expect(
      SettingsSchema.safeParse(withOverrides({ payMode: 'hourly', payAmount: 12_000 })).success,
    ).toBe(true)
  })

  it('점심을 끈 설정을 통과시킨다', () => {
    expect(SettingsSchema.safeParse(withOverrides({ lunchEnabled: false })).success).toBe(true)
  })

  it('자정을 넘는 야간근무를 통과시킨다', () => {
    const s = withOverrides({
      workStart: '22:00',
      workEnd: '06:00',
      lunchStart: '01:00',
      lunchMinutes: 60,
    })
    expect(SettingsSchema.safeParse(s).success).toBe(true)
  })

  it('급여가 0 이하면 거부한다', () => {
    expect(SettingsSchema.safeParse(withOverrides({ payAmount: 0 })).success).toBe(false)
    expect(SettingsSchema.safeParse(withOverrides({ payAmount: -1 })).success).toBe(false)
  })

  it('시각 형식이 틀리면 거부한다', () => {
    expect(SettingsSchema.safeParse(withOverrides({ workStart: '9:00' })).success).toBe(false)
  })

  it('출근과 퇴근이 같으면 거부한다', () => {
    expect(
      SettingsSchema.safeParse(withOverrides({ workStart: '09:00', workEnd: '09:00' })).success,
    ).toBe(false)
  })

  it('11:30에 2시간 점심을 통과시킨다', () => {
    const s = withOverrides({ lunchStart: '11:30', lunchMinutes: 120 })
    expect(SettingsSchema.safeParse(s).success).toBe(true)
  })

  it('두 시간 비우고 무급은 한 시간인 경우를 통과시킨다', () => {
    const s = withOverrides({ lunchStart: '11:30', lunchMinutes: 60 })
    expect(SettingsSchema.safeParse(s).success).toBe(true)
  })

  it('무급 시간이 0분이면 거부한다', () => {
    expect(SettingsSchema.safeParse(withOverrides({ lunchMinutes: 0 })).success).toBe(false)
  })

  it('점심이 근무구간 밖이면 거부한다', () => {
    expect(SettingsSchema.safeParse(withOverrides({ lunchStart: '20:00' })).success).toBe(false)
  })

  it('점심이 퇴근을 넘어가면 거부한다', () => {
    const s = withOverrides({ lunchStart: '17:30', lunchMinutes: 60 })
    expect(SettingsSchema.safeParse(s).success).toBe(false)
  })

  it('무급 시간이 근무시간 전체를 먹으면 거부한다', () => {
    const s = withOverrides({ workStart: '09:00', workEnd: '10:00', lunchMinutes: 60 })
    expect(SettingsSchema.safeParse(s).success).toBe(false)
  })

  it('점심을 껐으면 점심 시각이 이상해도 통과시킨다', () => {
    const s = withOverrides({ lunchEnabled: false, lunchStart: '20:00', lunchMinutes: 600 })
    expect(SettingsSchema.safeParse(s).success).toBe(true)
  })

  it('공제율을 직접 지정할 수 있다', () => {
    expect(SettingsSchema.safeParse(withOverrides({ netPay: true, deductionRate: 0.119 })).success).toBe(true)
  })

  it('공제율이 90%를 넘으면 거부한다', () => {
    expect(SettingsSchema.safeParse(withOverrides({ deductionRate: 0.95 })).success).toBe(false)
  })

  it('근무일수가 0 이하면 거부한다', () => {
    expect(SettingsSchema.safeParse(withOverrides({ workDaysPerMonth: 0 })).success).toBe(false)
  })
})
