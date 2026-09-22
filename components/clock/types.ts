import type { Shift } from '@/lib/shift'

/** 모든 페이스가 같은 좌표계를 쓴다. viewBox="0 0 200 200" */
export const CX = 100
export const CY = 100

export interface ClockFaceProps {
  now: number
  shift: Shift
  /** 바깥에서 크기를 정한다. 페이스는 지름을 모른다 */
  className?: string
}
