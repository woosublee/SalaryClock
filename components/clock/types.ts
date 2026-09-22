import type { Shift } from '@/lib/shift'

/** 모든 페이스가 같은 좌표계를 쓴다. viewBox="0 0 200 200" */
export const CX = 100
export const CY = 100

export interface ClockFaceProps {
  now: number
  /** 휴무일이면 null. 근무 구간을 그리지 않는다 */
  shift: Shift | null
  /** 바깥에서 크기를 정한다. 페이스는 지름을 모른다 */
  className?: string
}
