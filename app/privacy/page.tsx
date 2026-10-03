import type { Metadata } from 'next'
import { DocPage, DocSection, ISSUES_URL } from '@/components/DocPage'

export const metadata: Metadata = {
  title: '개인정보 처리방침 · SalaryClock',
  description: 'SalaryClock 웹·macOS·iOS 앱의 개인정보 처리방침',
}

export default function PrivacyPage() {
  return (
    <DocPage title="개인정보 처리방침" updated="2026년 10월 3일">
      <p>
        SalaryClock(웹, macOS 앱, iOS 앱. 이하 &ldquo;서비스&rdquo;)은 이용자의 개인정보를
        수집하지 않습니다. 이 문서는 서비스가 어떤 정보를 어디에 두는지 설명합니다.
      </p>

      <DocSection title="1. 수집하는 개인정보">
        <p>
          서비스는 회원가입·로그인이 없고, 이름·이메일·연락처·기기 식별자·위치 등 어떤 개인정보도
          수집하지 않습니다. 광고, 분석(애널리틱스), 사용자 추적 도구도 쓰지 않습니다.
        </p>
      </DocSection>

      <DocSection title="2. 이용자가 입력한 설정값">
        <p>
          급여, 근무 시간, 점심시간, 근무일, 공제율, 화면 설정 등 이용자가 입력한 값은 이용자의
          기기 안에만 저장됩니다.
        </p>
        <ul className="list-disc space-y-1 pl-5">
          <li>웹: 브라우저의 로컬 저장소(localStorage)</li>
          <li>macOS·iOS 앱: 기기의 앱 설정 저장소(UserDefaults)</li>
        </ul>
        <p>
          금액 계산도 전부 기기 안에서 이뤄지며, 이 값들은 개발자를 포함한 누구에게도 전송되지
          않습니다. 앱을 삭제하거나 브라우저 데이터를 지우면 함께 삭제되고, 앱의 &ldquo;설정
          초기화&rdquo;로도 지울 수 있습니다.
        </p>
      </DocSection>

      <DocSection title="3. 제3자 제공 및 처리 위탁">
        <p>서비스는 개인정보를 제3자에게 제공하거나 처리를 위탁하지 않습니다.</p>
        <p>
          다만 서비스를 이용하는 과정에서 다음 업체와 통신이 일어나며, 이때 IP 주소 등 일반적인
          접속 정보가 해당 업체의 정책에 따라 기록될 수 있습니다.
        </p>
        <ul className="list-disc space-y-1 pl-5">
          <li>웹: 웹사이트를 제공하는 호스팅 업체</li>
          <li>macOS 앱: 새 버전을 확인할 때 접속하는 GitHub</li>
          <li>iOS 앱: 하루 한 번 공휴일 자료를 받아올 때 접속하는 GitHub</li>
          <li>iOS 앱: 앱 설치·업데이트를 제공하는 Apple App Store</li>
        </ul>
        <p>
          공휴일 자료는 누구에게나 같은 공개 파일을 내려받는 것이며, 요청에는 쿠키나 기기
          식별자, 이용자가 입력한 설정값이 담기지 않습니다.
        </p>
      </DocSection>

      <DocSection title="4. 아동의 개인정보">
        <p>서비스는 연령과 관계없이 어떤 개인정보도 수집하지 않습니다.</p>
      </DocSection>

      <DocSection title="5. 방침의 변경">
        <p>
          이 방침이 바뀌면 이 페이지에 바뀐 내용과 시행일을 게시합니다.
        </p>
      </DocSection>

      <DocSection title="6. 문의">
        <p>
          개인정보와 관련한 문의는{' '}
          <a href={ISSUES_URL} className="underline underline-offset-2">
            GitHub 이슈
          </a>
          로 남겨 주세요.
        </p>
      </DocSection>
    </DocPage>
  )
}
