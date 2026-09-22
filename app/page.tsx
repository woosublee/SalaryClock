'use client'

import { useState } from 'react'
import { useNow } from '@/hooks/useNow'
import { useSettings } from '@/hooks/useSettings'
import { computeEarnings } from '@/lib/salary'
import { workdayInfo } from '@/lib/workdays'
import { AnalogClock } from '@/components/AnalogClock'
import { DateLine } from '@/components/DateLine'
import { EarningsDisplay } from '@/components/EarningsDisplay'
import { StatusLine } from '@/components/StatusLine'
import { SettingsPanel } from '@/components/SettingsPanel'

export default function Home() {
  const now = useNow()
  const { settings, isLoaded, hasStored, revision, update, reset } = useSettings()
  const [panelOpen, setPanelOpen] = useState(false)

  const earnings = computeEarnings(settings, now)

  // 저장된 설정이 없는 첫 방문(또는 초기화 직후)이면 설정부터 연다.
  const firstRun = isLoaded && !hasStored
  const showPanel = panelOpen || firstRun

  // 시계와 금액은 현재 시각에 의존하므로 서버 렌더 결과가 클라이언트와 반드시
  // 어긋난다. 저장값을 읽기 전까지는 아무것도 그리지 않아 불일치를 피한다.
  if (!isLoaded) {
    return (
      <main className="flex min-h-dvh items-center justify-center bg-white dark:bg-slate-950" />
    )
  }

  return (
    <main className="relative flex min-h-dvh flex-col items-center justify-center gap-6 bg-white px-4 py-10 text-slate-900 dark:bg-slate-950 dark:text-slate-100">
      <div className="absolute right-4 top-4 flex items-center gap-1">
        <button
          onClick={() => update({ ...settings, hideAmount: !settings.hideAmount })}
          aria-label={settings.hideAmount ? '금액 보이기' : '금액 가리기'}
          aria-pressed={settings.hideAmount}
          title={settings.hideAmount ? '금액 보이기' : '금액 가리기'}
          className="rounded-lg p-2 text-slate-400 transition-colors hover:text-slate-700 dark:hover:text-slate-200"
        >
          <EyeIcon off={settings.hideAmount} />
        </button>
        <button
          onClick={() => setPanelOpen(true)}
          aria-label="설정 열기"
          className="rounded-lg p-2 text-xl leading-none text-slate-400 transition-colors hover:text-slate-700 dark:hover:text-slate-200"
        >
          ⚙
        </button>
      </div>

      <DateLine
        now={now}
        workDays={earnings.workDays}
        monthInfo={workdayInfo(now)}
        isAutoWorkDays={settings.workDaysMode === 'auto'}
        workStart={settings.workStart}
        workEnd={settings.workEnd}
        paidHours={earnings.totalPaidMs / 3_600_000}
      />

      <AnalogClock now={now} shift={earnings.shift} style={settings.clockStyle} />
      <EarningsDisplay earnings={earnings} hidden={settings.hideAmount} />
      <StatusLine earnings={earnings} hidden={settings.hideAmount} />

      {showPanel && (
        // revision을 key로 주면 설정이 바뀔 때마다 폼이 새로 마운트된다.
        // 초기화를 눌렀을 때 입력칸이 기본값으로 되돌아오는 것도 이것 덕분이다.
        <SettingsPanel
          key={revision}
          settings={settings}
          now={now}
          onSave={update}
          onReset={reset}
          onClose={() => setPanelOpen(false)}
          dismissable={!firstRun}
        />
      )}
    </main>
  )
}

function EyeIcon({ off }: { off: boolean }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
      className="size-5"
      aria-hidden="true"
    >
      <path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7-10-7-10-7Z" />
      <circle cx="12" cy="12" r="3" />
      {off && <line x1="3" y1="21" x2="21" y2="3" />}
    </svg>
  )
}
