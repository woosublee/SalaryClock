import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { STORAGE_KEY } from "@/lib/settings";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "SalaryClock",
  description: "지금 이 순간 내 월급이 얼마나 쌓였는지 보여주는 시계",
};

/*
 * 저장된 테마를 첫 페인트 전에 <html>에 붙인다.
 *
 * 서버는 localStorage를 모르므로 data-theme 없이 그리고, CSS는 그때 기기 설정을
 * 따른다. 기기는 밝은데 어둡게를 저장해 둔 사람은 React가 붙어 page.tsx의
 * effect가 돌 때까지 흰 화면을 한 번 본다. 이 스크립트는 HTML을 파싱하는 도중에
 * 동기로 돌아 그 틈을 없앤다. 스크립트가 속성을 바꾸므로 <html>의 하이드레이션
 * 불일치 경고는 끈다 — DOM에 있는 값이 맞는 값이다.
 */
const THEME_SCRIPT = `try{var s=JSON.parse(localStorage.getItem(${JSON.stringify(STORAGE_KEY)}));if(s&&(s.theme==="dark"||s.theme==="light"))document.documentElement.dataset.theme=s.theme}catch(e){}`;

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="ko"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
      suppressHydrationWarning
    >
      <head>
        <script dangerouslySetInnerHTML={{ __html: THEME_SCRIPT }} />
      </head>
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
