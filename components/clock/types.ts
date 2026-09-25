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
  /**
   * 화면 읽기 프로그램이 읽을 이름. 없으면 장식으로 보고 숨긴다 — 설정 창의
   * 미리보기는 버튼 글자(페이스 이름)가 이미 설명하므로 그림을 또 읽을 필요가 없다.
   */
  label?: string
}

/** 페이스 SVG에 붙일 접근성 속성 */
export function faceA11y(label: string | undefined) {
  return label ? { role: 'img', 'aria-label': label } : { 'aria-hidden': true }
}
