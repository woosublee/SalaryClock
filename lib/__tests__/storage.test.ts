import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import {
  loadSettings,
  saveSettings,
  clearSettings,
  DEFAULT_SETTINGS,
  STORAGE_KEY,
  type Settings,
} from '@/lib/settings'

/** 브라우저 없이 localStorage와 다크모드 설정만 흉내낸다 */
function installFakeStorage(prefersDark = false) {
  const store = new Map<string, string>()
  const localStorage = {
    getItem: (k: string) => store.get(k) ?? null,
    setItem: (k: string, v: string) => void store.set(k, v),
    removeItem: (k: string) => void store.delete(k),
  }
  const matchMedia = (q: string) => ({ matches: q.includes('dark') ? prefersDark : false })
  ;(globalThis as { window?: unknown }).window = { localStorage, matchMedia }
  return store
}

/** 필드가 추가되기 전에 저장된 값을 흉내낸다 */
function without(s: Settings, ...keys: (keyof Settings)[]): Partial<Settings> {
  const copy: Partial<Settings> = { ...s }
  for (const k of keys) delete copy[k]
  return copy
}

describe('localStorage 저장', () => {
  let store: Map<string, string>

  beforeEach(() => {
    store = installFakeStorage()
  })

  afterEach(() => {
    delete (globalThis as { window?: unknown }).window
  })

  it('저장된 값이 없으면 기본값을 주고 hasStored가 false다', () => {
    const loaded = loadSettings()
    expect(loaded.settings).toEqual(DEFAULT_SETTINGS)
    expect(loaded.hasStored).toBe(false)
  })

  it('첫 방문에는 테마를 기기 설정에서 가져온다', () => {
    installFakeStorage(true)
    expect(loadSettings().settings.theme).toBe('dark')

    installFakeStorage(false)
    expect(loadSettings().settings.theme).toBe('light')
  })

  it('저장된 테마가 있으면 기기 설정을 무시한다', () => {
    installFakeStorage(true)
    saveSettings({ ...DEFAULT_SETTINGS, theme: 'light' })
    expect(loadSettings().settings.theme).toBe('light')
  })

  it('설정 전체가 한 덩어리로 저장된다', () => {
    saveSettings(DEFAULT_SETTINGS)
    const raw = JSON.parse(store.get(STORAGE_KEY)!)
    expect(Object.keys(raw).sort()).toEqual(Object.keys(DEFAULT_SETTINGS).sort())
  })

  it('모든 필드가 그대로 왕복한다', () => {
    const custom: Settings = {
      payMode: 'monthly',
      payAmount: 4_200_000,
      workDaysMode: 'calendar',
      workDaysPerMonth: 19,
      dayOverrides: ['2026-09-21', '2026-09-25'],
      workStart: '10:30',
      workEnd: '19:30',
      lunchEnabled: true,
      lunchStart: '11:30',
      lunchMinutes: 120,
      netPay: true,
      deductionRate: 0.142,
      clockStyle: 'grain',
      hideAmount: true,
      theme: 'dark',
    }

    saveSettings(custom)
    const loaded = loadSettings()

    expect(loaded.settings).toEqual(custom)
    expect(loaded.hasStored).toBe(true)
  })

  it('달력에서 찍은 날짜도 살아남는다', () => {
    saveSettings({ ...DEFAULT_SETTINGS, dayOverrides: ['2026-09-22'] })
    expect(loadSettings().settings.dayOverrides).toEqual(['2026-09-22'])
  })

  it('시계 페이스와 금액 가리기도 살아남는다', () => {
    saveSettings({ ...DEFAULT_SETTINGS, clockStyle: 'rings', hideAmount: true })
    const s = loadSettings().settings
    expect(s.clockStyle).toBe('rings')
    expect(s.hideAmount).toBe(true)
  })

  it('테마 설정도 살아남는다', () => {
    saveSettings({ ...DEFAULT_SETTINGS, theme: 'dark' })
    expect(loadSettings().settings.theme).toBe('dark')
  })

  it('실수령 설정과 공제율도 살아남는다', () => {
    saveSettings({ ...DEFAULT_SETTINGS, netPay: true, deductionRate: 0.2 })
    const s = loadSettings().settings
    expect(s.netPay).toBe(true)
    expect(s.deductionRate).toBe(0.2)
  })

  it('저장값이 깨졌으면 기본값으로 되돌린다', () => {
    store.set(STORAGE_KEY, '{ 이건 JSON이 아님')
    const loaded = loadSettings()
    expect(loaded.settings).toEqual(DEFAULT_SETTINGS)
    expect(loaded.hasStored).toBe(false)
  })

  it('스키마에 안 맞는 값이면 기본값으로 되돌린다', () => {
    store.set(STORAGE_KEY, JSON.stringify({ ...DEFAULT_SETTINGS, payAmount: -1 }))
    expect(loadSettings().settings).toEqual(DEFAULT_SETTINGS)
  })

  it('필드가 추가되기 전에 저장한 값도 살리고 없는 필드만 기본값으로 채운다', () => {
    const older = without(
      { ...DEFAULT_SETTINGS, payMode: 'monthly', payAmount: 3_500_000, dayOverrides: ['2026-09-22'] },
      'theme',
      'clockStyle',
    )
    store.set(STORAGE_KEY, JSON.stringify(older))

    const loaded = loadSettings()
    expect(loaded.hasStored).toBe(true)
    expect(loaded.settings.payMode).toBe('monthly')
    expect(loaded.settings.payAmount).toBe(3_500_000)
    expect(loaded.settings.dayOverrides).toEqual(['2026-09-22'])
    expect(loaded.settings.clockStyle).toBe(DEFAULT_SETTINGS.clockStyle)
  })

  it('빠진 테마는 첫 방문처럼 기기 설정에서 가져온다', () => {
    installFakeStorage(true).set(STORAGE_KEY, JSON.stringify(without(DEFAULT_SETTINGS, 'theme')))
    expect(loadSettings().settings.theme).toBe('dark')
  })

  it('예전 버전에만 있던 필드(lunchEnd)는 버리고 나머지를 살린다', () => {
    store.set(STORAGE_KEY, JSON.stringify({ payMode: 'hourly', payAmount: 12_000, lunchEnd: '13:00' }))
    const loaded = loadSettings()
    expect(loaded.hasStored).toBe(true)
    expect(loaded.settings.payMode).toBe('hourly')
    expect(loaded.settings).not.toHaveProperty('lunchEnd')
  })

  it('저장값이 객체가 아니면 기본값으로 되돌린다', () => {
    store.set(STORAGE_KEY, JSON.stringify([1, 2, 3]))
    expect(loadSettings().hasStored).toBe(false)
    store.set(STORAGE_KEY, 'null')
    expect(loadSettings().hasStored).toBe(false)
  })

  it('초기화하면 저장값이 지워진다', () => {
    saveSettings(DEFAULT_SETTINGS)
    expect(store.has(STORAGE_KEY)).toBe(true)
    clearSettings()
    expect(store.has(STORAGE_KEY)).toBe(false)
    expect(loadSettings().hasStored).toBe(false)
  })
})

describe('서버 렌더 환경', () => {
  it('window가 없으면 기본값을 주고 터지지 않는다', () => {
    delete (globalThis as { window?: unknown }).window
    expect(loadSettings().settings).toEqual(DEFAULT_SETTINGS)
    expect(() => saveSettings(DEFAULT_SETTINGS)).not.toThrow()
    expect(() => clearSettings()).not.toThrow()
  })
})
