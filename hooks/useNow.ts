'use client'

import { useEffect, useState } from 'react'

/**
 * 앱의 유일한 시간 소스.
 *
 * rAF로 매 프레임 갱신하므로 초침이 끊기지 않고 흐르고, 시계 바늘과 금액이
 * 같은 틱에서 나와 서로 어긋나지 않는다. 탭이 백그라운드로 가면 rAF가 멈췄다가
 * 돌아올 때 현재 시각으로 다시 계산하므로 보정이 필요 없다.
 *
 * prefers-reduced-motion이면 1초에 한 번으로 낮춘다. 벽시계의 초 경계에 맞춰
 * 깨어나므로 표시되는 초가 실제보다 늦게 넘어가거나 한 칸씩 건너뛰지 않는다.
 * 앱을 켜 둔 채 OS 설정을 바꿔도 곧바로 따라간다.
 */
export function useNow(): number {
  const [now, setNow] = useState(() => Date.now())
  const [reduced, setReduced] = useState(false)

  useEffect(() => {
    const mql = window.matchMedia('(prefers-reduced-motion: reduce)')
    const sync = () => setReduced(mql.matches)
    sync()
    mql.addEventListener('change', sync)
    return () => mql.removeEventListener('change', sync)
  }, [])

  useEffect(() => {
    if (reduced) {
      let id = 0
      const tick = () => {
        const t = Date.now()
        setNow(t)
        // 다음 초의 경계를 막 넘긴 순간. setInterval은 시작 시점에서 1초씩 재므로
        // 경계와 최대 1초 어긋나고, 밀리면 초 하나를 건너뛴다.
        id = window.setTimeout(tick, 1000 - (t % 1000) + 1)
      }
      tick()
      return () => window.clearTimeout(id)
    }

    let frame = 0
    const tick = () => {
      setNow(Date.now())
      frame = window.requestAnimationFrame(tick)
    }
    frame = window.requestAnimationFrame(tick)
    return () => window.cancelAnimationFrame(frame)
  }, [reduced])

  return now
}
