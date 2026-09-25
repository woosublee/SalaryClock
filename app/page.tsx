'use client'

import { useEffect, useState } from 'react'
import { useNow } from '@/hooks/useNow'
import { useSettings } from '@/hooks/useSettings'
import { computeEarnings } from '@/lib/salary'
import { workdayInfo } from '@/lib/workdays'
import { resolveShift } from '@/lib/shift'
import type { ThemeMode } from '@/lib/settings'
import { AnalogClock } from '@/components/AnalogClock'
import { DateLine } from '@/components/DateLine'
import { EarningsDisplay } from '@/components/EarningsDisplay'
import { TimeDisplay } from '@/components/TimeDisplay'
import { StatusLine } from '@/components/StatusLine'
import { SettingsPanel } from '@/components/SettingsPanel'

const THEME_LABELS: Record<ThemeMode, string> = {
  light: '어두운 화면으로',
  dark: '밝은 화면으로',
}

export default function Home() {
  const now = useNow()
  const { settings, isLoaded, hasStored, revision, update, reset } = useSettings()
  const [panelOpen, setPanelOpen] = useState(false)

  /*
   * 테마를 <html>의 data-theme으로 내보낸다. CSS가 이 속성을 읽어 색을 정한다.
   *
   * 서버가 그린 HTML에는 이 속성이 없고, 그때는 CSS가 기기 설정을 따른다.
   * 첫 방문의 저장값도 기기 설정에서 가져오므로(loadSettings) 자바스크립트가
   * 붙는 순간 색이 바뀌어 번쩍이는 일이 없다.
   */
  useEffect(() => {
    document.documentElement.dataset.theme = settings.theme
  }, [settings.theme])

  const earnings = computeEarnings(settings, now)
  // 근무일수(earnings.workDays)는 시프트가 시작한 달로 센다. 공휴일 안내도 같은
  // 달로 맞춘다 — now로 보면 월말 야간근무가 자정을 넘는 순간 "이번 달 N일"은
  // 지난달, "(공휴일 M일 제외)"는 새 달 값이 한 줄에 섞인다.
  const monthInfo = workdayInfo(resolveShift(settings, now).startMs)

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

  const toggleTheme = () =>
    update({ ...settings, theme: settings.theme === 'dark' ? 'light' : 'dark' })

  const iconButton =
    'rounded-lg p-2 text-slate-400 transition-colors hover:text-slate-700 dark:hover:text-slate-200'

  // 쉬는 날에는 가리기 화면을 그대로 쓴다. 날짜와 시각만 남아 앱이 시계가 된다.
  const dayOff = earnings.phase === 'dayoff'
  const minimal = settings.hideAmount || dayOff

  return (
    <main className="relative flex min-h-dvh flex-col items-center justify-center gap-6 bg-white px-4 py-10 text-slate-900 dark:bg-slate-950 dark:text-slate-100">
      <div className="absolute right-4 top-4 flex items-center gap-1">
        <button
          onClick={toggleTheme}
          aria-label={THEME_LABELS[settings.theme]}
          title={THEME_LABELS[settings.theme]}
          className={iconButton}
        >
          <ThemeIcon mode={settings.theme} />
        </button>
        {!dayOff && (
          <button
            onClick={() => update({ ...settings, hideAmount: !settings.hideAmount })}
            aria-label={settings.hideAmount ? '금액 보이기' : '금액 가리기'}
            aria-pressed={settings.hideAmount}
            title={settings.hideAmount ? '금액 보이기' : '금액 가리기'}
            className={iconButton}
          >
            <EyeIcon off={settings.hideAmount} />
          </button>
        )}
        <button onClick={() => setPanelOpen(true)} aria-label="설정 열기" className={iconButton}>
          <GearIcon />
        </button>
      </div>

      <DateLine
        now={now}
        workDays={earnings.workDays}
        monthInfo={monthInfo}
        isAutoWorkDays={settings.workDaysMode === 'auto'}
        workStart={settings.workStart}
        workEnd={settings.workEnd}
        paidHours={earnings.totalPaidMs / 3_600_000}
        minimal={minimal}
      />

      <AnalogClock now={now} shift={earnings.shift} style={settings.clockStyle} />

      {/*
        가린 상태에서는 금액과 상태 문구를 내리고 시각만 남긴다. 남은 시간은
        TimeDisplay가 시각 바로 아래에 붙인다. 두 블록과 아래 상태줄은 높이를
        똑같이 유지하므로 가리기를 눌러도 시계가 제자리에 있는다.
      */}
      {minimal ? (
        <TimeDisplay now={now} earnings={earnings} />
      ) : (
        <EarningsDisplay earnings={earnings} />
      )}

      <StatusLine earnings={earnings} settings={settings} now={now} hidden={minimal} />

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

/*
 * 톱니바퀴를 문자(U+2699)로 쓰면 iOS에서 컬러 이모지로 바뀐다. 애플 시스템
 * 폰트에 이 문자의 텍스트 글리프가 없어서 Apple Color Emoji로 대체되기 때문이다.
 * 변이 선택자(U+FE0E)를 붙여도 대체할 텍스트 글리프 자체가 없어 소용이 없다.
 * 나머지 아이콘과 같이 SVG로 그린다.
 */
function GearIcon() {
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
      <path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z" />
      <circle cx="12" cy="12" r="3" />
    </svg>
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

/** 지금 상태가 아니라 누르면 가게 될 상태를 그린다 */
function ThemeIcon({ mode }: { mode: ThemeMode }) {
  const common = {
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 1.75,
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
    className: 'size-5',
    'aria-hidden': true,
  }

  // 밝은 화면이면 달(어둡게 가기), 어두운 화면이면 해(밝게 가기)
  if (mode === 'light') {
    return (
      <svg {...common}>
        <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z" />
      </svg>
    )
  }

  return (
    <svg {...common}>
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
    </svg>
  )
}
