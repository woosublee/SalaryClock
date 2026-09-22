'use client'

import { useEffect, useState } from 'react'

/**
 * 앱의 유일한 시간 소스.
 *
 * rAF로 매 프레임 갱신하므로 초침이 끊기지 않고 흐르고, 시계 바늘과 금액이
 * 같은 틱에서 나와 서로 어긋나지 않는다. 탭이 백그라운드로 가면 rAF가 멈췄다가
 * 돌아올 때 현재 시각으로 다시 계산하므로 보정이 필요 없다.
 *
 * prefers-reduced-motion이면 1초 간격으로 낮춘다.
 */
export function useNow(): number {
  const [now, setNow] = useState(() => Date.now())

  useEffect(() => {
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches

    if (reduced) {
      const id = window.setInterval(() => setNow(Date.now()), 1000)
      return () => window.clearInterval(id)
    }

    let frame = 0
    const tick = () => {
      setNow(Date.now())
      frame = window.requestAnimationFrame(tick)
    }
    frame = window.requestAnimationFrame(tick)
    return () => window.cancelAnimationFrame(frame)
  }, [])

  return now
}
