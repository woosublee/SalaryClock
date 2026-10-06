import type { Metadata } from 'next'
import { DocPage, DocSection, ISSUES_URL } from '@/components/DocPage'

export const metadata: Metadata = {
  title: '지원 · SalaryClock',
  description: 'SalaryClock 사용 안내와 문의',
}

export default function SupportPage() {
  return (
    <DocPage title="SalaryClock 지원">
      <p>
        SalaryClock은 지금 이 순간까지 오늘 번 금액을 실시간으로 보여주는 시계입니다. 연봉·월급·시급과
        근무 시간을 넣으면 출근부터 퇴근까지 금액이 초 단위로 올라갑니다.
      </p>

      <DocSection title="문의하기">
        <p>
          버그 신고, 기능 제안, 그 밖의 문의는{' '}
          <a href={ISSUES_URL} className="underline underline-offset-2">
            GitHub 이슈
          </a>
          에 남겨 주세요. 사용 중인 기기(아이폰·Mac·브라우저)와 앱 버전을 함께 적어 주시면 빨리
          확인할 수 있습니다. iOS 앱 버전은 아이폰 설정 › 일반 › iPhone 저장 공간 › SalaryClock에서,
          Mac 앱 버전은 SalaryClock 설정 창 맨 아래에서 볼 수 있습니다.
        </p>
      </DocSection>

      <DocSection title="자주 묻는 질문">
        <dl className="space-y-5">
          <div>
            <dt className="font-medium text-slate-900 dark:text-slate-100">
              실수령액이 급여명세서와 다릅니다.
            </dt>
            <dd className="mt-1">
              4대보험은 법정 요율로 계산하지만 소득세는 부양가족 수 등을 알 수 없어 추정치입니다.
              설정 › 급여에서 &ldquo;실수령액 기준으로 보기&rdquo;를 켜고, 명세서의{' '}
              <code>공제 합계 ÷ 세전 금액</code>을 공제율에 직접 넣으면 정확해집니다.
            </dd>
          </div>
          <div>
            <dt className="font-medium text-slate-900 dark:text-slate-100">
              연차를 쓴 날이나 주말 출근은 어떻게 반영하나요?
            </dt>
            <dd className="mt-1">
              설정 › 근무일수 › 달력에서 고르기에서 날짜를 누르면 근무일과 쉬는 날이 바뀝니다.
              다음 달 날짜도 미리 찍어 둘 수 있습니다.
            </dd>
          </div>
          <div>
            <dt className="font-medium text-slate-900 dark:text-slate-100">공휴일은 언제까지 들어 있나요?</dt>
            <dd className="mt-1">
              2030년까지 들어 있습니다. 2028년 이후는 관보 확정 전이라 바뀔 수 있으며, 표에 없는
              해는 주말만 빼고 계산합니다. 선거일처럼 공고로 정해지는 날은 달력에서 직접 찍어 주세요.
            </dd>
          </div>
          <div>
            <dt className="font-medium text-slate-900 dark:text-slate-100">
              아이폰과 Mac, 웹의 설정이 서로 이어지나요?
            </dt>
            <dd className="mt-1">
              아니요. 설정은 각 기기에만 저장되고 어디로도 전송되지 않으므로, 기기마다 한 번씩
              입력해야 합니다.
            </dd>
          </div>
          <div>
            <dt className="font-medium text-slate-900 dark:text-slate-100">금액 가리기는 무엇인가요?</dt>
            <dd className="mt-1">
              눈 모양 버튼을 누르면 금액 대신 현재 시각을 보여줍니다. 주변 시선을 가리는 용도이며
              보안 기능은 아닙니다.
            </dd>
          </div>
        </dl>
      </DocSection>
    </DocPage>
  )
}
