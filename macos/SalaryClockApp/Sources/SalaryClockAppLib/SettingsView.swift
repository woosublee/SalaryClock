import SwiftUI
import ServiceManagement
import SalaryClockCore

/// 웹 SettingsPanel에서 맥이 쓰는 항목만 남긴 폼.
///
/// macOS 기본 Form 스타일(회색 배경, 오른쪽 정렬 라벨)을 쓰지 않는다 —
/// 그러면 웹과 다른 화면이 된다. 라벨을 왼쪽 위에 두고 입력칸을 폭 가득
/// 채우는 웹의 배치를 따른다.
struct SettingsView: View {
    var onDone: () -> Void

    // SwiftUI도 Settings라는 타입(Settings 씬)을 갖고 있어 이름이 겹친다 —
    // PopoverView의 TickModel과 같은 이유로 항상 core 쪽을 가리키도록 모듈명을 붙인다.
    @State private var draft: SalaryClockCore.Settings = SettingsStore.shared.settings
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    // 공제율 직접 입력 섹션을 펼쳤는지 — 웹 SettingsPanel의 showAdvanced와 같다.
    @State private var showAdvanced = false
    @Environment(\.colorScheme) private var scheme

    private var theme: Theme { Theme(scheme: scheme) }
    private var isValid: Bool { SettingsStore.isValid(draft) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("설정").font(.system(size: 18, weight: .bold))

            field("급여") {
                Picker("", selection: $draft.payMode) {
                    Text("연봉").tag(PayMode.annual)
                    Text("월급").tag(PayMode.monthly)
                    Text("시급").tag(PayMode.hourly)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                TextField("", value: $draft.payAmount, format: .number)
                    .textFieldStyle(.roundedBorder)
                Text(formatKoreanUnits(draft.payAmount))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.dim)
            }

            field("근무 시간") {
                HStack {
                    timeField($draft.workStart)
                    Text("–").foregroundStyle(theme.dim)
                    timeField($draft.workEnd)
                }
            }

            field("점심") {
                Toggle("점심시간 제외", isOn: $draft.lunchEnabled)
                if draft.lunchEnabled {
                    HStack {
                        timeField($draft.lunchStart)
                        Text("–").foregroundStyle(theme.dim)
                        timeField(lunchEndBinding)
                    }
                    Text("무급 \(draft.lunchMinutes)분")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.dim)
                }
            }

            Toggle("실수령액 기준으로 보기", isOn: $draft.netPay)
            // 같은 급여를 넣어도 웹과 맥이 다른 금액을 보여준 원인 중 하나가
            // 이 필드의 부재였다 — 근무일수(auto)는 웹과 같은 계산이라 문제가
            // 아니었고, 공제율을 웹은 직접 입력할 수 있는데 맥은 항상 추정치만
            // 썼다. deductionRate가 nil이면 추정치를, 있으면 그 값을 그대로
            // 쓴다 (SalaryClockCore.deductionRateFor).
            if draft.netPay {
                deductionSection
            }
            Toggle("로그인할 때 자동 실행", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    // 등록이 실패해도 앱은 계속 돌아야 한다. 토글만 되돌린다.
                    do {
                        if on { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            if !isValid {
                Text("설정값이 올바르지 않습니다")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("닫기", action: onDone)
                Button("저장") {
                    SettingsStore.shared.settings = draft
                    onDone()
                }
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(theme.background)
    }

    @ViewBuilder
    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(theme.secondary)
            content()
        }
    }

    /// 점심은 시작~종료 시각으로 입력받고, 저장은 무급 분(lunchStart + lunchMinutes)으로
    /// 한다 — 웹 SettingsPanel의 lunchEndValue/setLunchEnd와 같은 구조다.
    ///
    /// 종료 시각을 읽을 때는 시작+무급분을 그대로 계산해서 보여주므로, 시작
    /// 시각을 바꾸면 무급 길이는 유지된 채 종료 시각이 따라 이동한다(값을
    /// 따로 맞춰주는 코드가 필요 없다). 종료 시각을 직접 바꾸면 그 차이만큼
    /// lunchMinutes를 다시 계산해 저장한다.
    private var lunchEndBinding: Binding<String> {
        Binding(
            get: {
                guard let start = parseHHmm(draft.lunchStart) else { return "13:00" }
                return formatHHmm(start + draft.lunchMinutes)
            },
            set: { newValue in
                guard isValidHHmm(newValue), let start = parseHHmm(draft.lunchStart),
                      let end = parseHHmm(newValue)
                else { return }
                draft.lunchMinutes = durationMinutes(start, end)
            }
        )
    }

    /// "HH:mm"을 그대로 받는다. 형식이 깨지면 저장 버튼이 잠긴다.
    private func timeField(_ value: Binding<String>) -> some View {
        TextField("HH:mm", text: value)
            .textFieldStyle(.roundedBorder)
            .frame(width: 70)
            .foregroundStyle(isValidHHmm(value.wrappedValue) ? theme.foreground : .red)
    }

    /// 지금 이 설정으로 계산한 월 세전 환산액. 공제율 추정치의 기준이 된다 —
    /// 웹 SettingsPanel의 previewShift/gross와 같다. draft가 아직 유효하지
    /// 않을 때(시각 입력 중 등)는 마지막으로 저장된 값으로 미리보기를
    /// 계산해 화면이 요동치지 않게 한다.
    private var previewGross: Double {
        let now = Int((Date().timeIntervalSince1970 * 1000).rounded())
        let s = isValid ? draft : SettingsStore.shared.settings
        let shift = resolveShift(s, now)
        let workDays = effectiveWorkDays(s, now)
        return monthlyGross(s, shift, workDays)
    }

    private var estimatedDeductions: Deductions { estimateDeductions(previewGross) }
    /// 실제로 적용되는 공제율 — 직접 입력했으면 그 값, 아니면 추정치.
    private var effectiveRate: Double { draft.deductionRate ?? estimatedDeductions.rate }

    /// 공제율 입력칸. 비우면 nil(추정치 사용), 숫자를 넣으면 그 값(0..1
    /// 분수)으로 저장한다 — 웹 SettingsPanel의 deductionRate 입력과 같다.
    private var deductionRateBinding: Binding<String> {
        Binding(
            get: {
                guard let r = draft.deductionRate else { return "" }
                return String(format: "%.1f", r * 100)
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    draft.deductionRate = nil
                } else if let pct = Double(trimmed) {
                    draft.deductionRate = pct / 100
                }
                // 숫자로 읽을 수 없는 중간 입력 상태는 무시하고 이전 값을 지킨다.
            }
        )
    }

    /// 실수령액 기준일 때만 의미가 있는 공제율 직접 입력 — 웹
    /// SettingsPanel의 "공제 내역 · 직접 설정" 펼침 구간과 같은 문구를 쓴다.
    private var deductionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("−\(String(format: "%.1f", effectiveRate * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.dim)
                Spacer()
                Button(showAdvanced ? "접기" : "공제 내역 · 직접 설정") {
                    showAdvanced.toggle()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .underline()
                .foregroundStyle(theme.dim)
            }

            if showAdvanced {
                HStack {
                    Text("공제율").font(.system(size: 11)).foregroundStyle(theme.dim)
                    TextField(
                        String(format: "%.1f", estimatedDeductions.rate * 100),
                        text: deductionRateBinding
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    Text("%").font(.system(size: 11)).foregroundStyle(theme.dim)
                }
                Text("비워두면 추정치를 씁니다. 명세서의 공제 합계 ÷ 세전 금액")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.dim)
            }
        }
    }
}
