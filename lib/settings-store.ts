import {
  DEFAULT_SETTINGS,
  clearSettings,
  loadSettings,
  saveSettings,
  type Settings,
} from '@/lib/settings'

export interface SettingsSnapshot {
  settings: Settings
  hasStored: boolean
  /** 클라이언트에서 localStorage를 실제로 읽었는지. 서버 렌더에서는 false */
  isLoaded: boolean
  /** 설정이 바뀔 때마다 증가. 입력 폼을 새로 마운트시키는 데 쓴다 */
  revision: number
}

/**
 * 서버 렌더와 하이드레이션 첫 렌더가 함께 쓰는 고정 스냅샷.
 * 참조가 매번 같아야 useSyncExternalStore가 무한 렌더로 빠지지 않는다.
 */
const SERVER_SNAPSHOT: SettingsSnapshot = {
  settings: DEFAULT_SETTINGS,
  hasStored: false,
  isLoaded: false,
  revision: 0,
}

let cache: SettingsSnapshot | null = null
const listeners = new Set<() => void>()

function emit(next: SettingsSnapshot): void {
  cache = next
  listeners.forEach((listener) => listener())
}

export function subscribe(listener: () => void): () => void {
  listeners.add(listener)
  return () => {
    listeners.delete(listener)
  }
}

export function getSnapshot(): SettingsSnapshot {
  if (!cache) {
    const loaded = loadSettings()
    cache = {
      settings: loaded.settings,
      hasStored: loaded.hasStored,
      isLoaded: true,
      revision: 1,
    }
  }
  return cache
}

export function getServerSnapshot(): SettingsSnapshot {
  return SERVER_SNAPSHOT
}

export function updateSettings(next: Settings): void {
  saveSettings(next)
  emit({
    settings: next,
    hasStored: true,
    isLoaded: true,
    revision: getSnapshot().revision + 1,
  })
}

/** 저장된 설정을 지우고 기본값으로 되돌린다. */
export function resetSettings(): void {
  clearSettings()
  emit({
    settings: DEFAULT_SETTINGS,
    hasStored: false,
    isLoaded: true,
    revision: getSnapshot().revision + 1,
  })
}
