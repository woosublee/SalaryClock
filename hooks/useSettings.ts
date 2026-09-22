'use client'

import { useSyncExternalStore } from 'react'
import {
  getServerSnapshot,
  getSnapshot,
  resetSettings,
  subscribe,
  updateSettings,
} from '@/lib/settings-store'

/**
 * useSyncExternalStore를 쓰는 이유: localStorage는 서버에 없다.
 * 서버 렌더와 하이드레이션 첫 렌더는 고정 스냅샷(isLoaded: false)을 쓰고,
 * 하이드레이션이 끝난 뒤에야 실제 저장값으로 갈아끼운다.
 * useEffect에서 setState 하는 방식보다 렌더 한 번을 덜 태운다.
 */
export function useSettings() {
  const snapshot = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot)

  return {
    settings: snapshot.settings,
    isLoaded: snapshot.isLoaded,
    hasStored: snapshot.hasStored,
    revision: snapshot.revision,
    update: updateSettings,
    reset: resetSettings,
  }
}
