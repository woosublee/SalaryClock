import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import {
  loadSettings,
  saveSettings,
  clearSettings,
  DEFAULT_SETTINGS,
  STORAGE_KEY,
  type Settings,
} from '@/lib/settings'

/** 브라우저 없이 localStorage 동작만 흉내낸다 */
function installFakeStorage() {
  const store = new Map<string, string>()
  const localStorage = {
    getItem: (k: string) => store.get(k) ?? null,
    setItem: (k: string, v: string) => void store.set(k, v),
    removeItem: (k: string) => void store.delete(k),
  }
  ;(globalThis as { window?: unknown }).window = { localStorage }
  return store
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

  it('예전 버전 형식(lunchEnd)이 남아 있으면 기본값으로 되돌린다', () => {
    store.set(STORAGE_KEY, JSON.stringify({ payMode: 'annual', lunchEnd: '13:00' }))
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
