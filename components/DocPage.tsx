import Link from 'next/link'

/*
 * 개인정보 처리방침·지원 페이지가 함께 쓰는 틀. App Store 심사가 두 URL을
 * 요구해서 생겼다. 시계 화면과 같은 색(slate)과 다크모드 규칙을 따른다.
 */
export function DocPage({
  title,
  updated,
  children,
}: {
  title: string
  updated?: string
  children: React.ReactNode
}) {
  return (
    <main className="min-h-dvh bg-white px-4 py-12 text-slate-700 dark:bg-slate-950 dark:text-slate-300">
      <article className="mx-auto max-w-2xl">
        <Link
          href="/"
          className="text-sm text-slate-500 underline underline-offset-2 hover:text-slate-700 dark:hover:text-slate-200"
        >
          ← SalaryClock
        </Link>
        <h1 className="mt-6 text-2xl font-bold text-slate-900 dark:text-slate-100">{title}</h1>
        {updated && <p className="mt-2 text-sm text-slate-500">시행일 {updated}</p>}
        <div className="mt-8 space-y-8 leading-relaxed">{children}</div>
        <nav className="mt-12 flex gap-4 border-t border-slate-200 pt-6 text-sm text-slate-500 dark:border-slate-800">
          <Link href="/support" className="underline underline-offset-2 hover:text-slate-700 dark:hover:text-slate-200">
            지원
          </Link>
          <Link href="/privacy" className="underline underline-offset-2 hover:text-slate-700 dark:hover:text-slate-200">
            개인정보 처리방침
          </Link>
        </nav>
      </article>
    </main>
  )
}

export function DocSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section>
      <h2 className="text-lg font-semibold text-slate-900 dark:text-slate-100">{title}</h2>
      <div className="mt-3 space-y-3">{children}</div>
    </section>
  )
}

export const ISSUES_URL = 'https://github.com/woosublee/SalaryClock/issues'
