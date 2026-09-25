'use client'

import type { Shift } from '@/lib/shift'
import type { ClockStyle } from '@/lib/settings'
import { MinimalFace } from '@/components/clock/MinimalFace'
import { NumeralsFace } from '@/components/clock/NumeralsFace'
import { GrainFace } from '@/components/clock/GrainFace'
import { RingsFace } from '@/components/clock/RingsFace'
import { SectorFace } from '@/components/clock/SectorFace'
import { DotsFace } from '@/components/clock/DotsFace'
import { CountdownFace } from '@/components/clock/CountdownFace'
import { LevelFace } from '@/components/clock/LevelFace'
import { SundialFace } from '@/components/clock/SundialFace'
import { PulseFace } from '@/components/clock/PulseFace'
import type { ClockFaceProps } from '@/components/clock/types'
import { formatClockTime } from '@/lib/format'

const FACES: Record<ClockStyle, (p: ClockFaceProps) => React.ReactElement> = {
  minimal: MinimalFace,
  numerals: NumeralsFace,
  grain: GrainFace,
  rings: RingsFace,
  sector: SectorFace,
  dots: DotsFace,
  countdown: CountdownFace,
  level: LevelFace,
  sundial: SundialFace,
  pulse: PulseFace,
}

export const CLOCK_STYLE_LABELS: Record<ClockStyle, string> = {
  minimal: '말끔',
  numerals: '숫자판',
  grain: '결',
  rings: '고리',
  sector: '채움',
  dots: '점',
  countdown: '남은',
  level: '수위',
  sundial: '해시계',
  pulse: '파문',
}

interface Props {
  now: number
  shift: Shift | null
  style: ClockStyle
  className?: string
  /** 미리보기처럼 옆 글자가 이미 설명하는 자리. 화면 읽기 프로그램에서 숨긴다 */
  decorative?: boolean
}

export function AnalogClock({
  now,
  shift,
  style,
  className = 'h-64 w-64 sm:h-72 sm:w-72',
  decorative = false,
}: Props) {
  const Face = FACES[style] ?? MinimalFace
  // 고정 문구 대신 실제 시각을 읽게 한다. 분까지만 — 초가 붙으면 읽는 도중에 바뀐다.
  const label = decorative ? undefined : `시계, ${formatClockTime(now).slice(0, 5)}`
  return <Face now={now} shift={shift} className={className} label={label} />
}
