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
}

export function AnalogClock({ now, shift, style, className = 'h-64 w-64 sm:h-72 sm:w-72' }: Props) {
  const Face = FACES[style] ?? MinimalFace
  return <Face now={now} shift={shift} className={className} />
}
