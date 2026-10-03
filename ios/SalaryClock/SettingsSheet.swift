import SwiftUI
import SalaryClockCore

/// iOS 설정 화면. 맥 SettingsView와 같은 항목·같은 규칙(SettingsStore.isValid,
/// SettingsFieldMath)을 쓰되, 배치는 iOS 설정 앱처럼 묶인 목록으로 둔다. 시각은
/// 직접 타이핑하지 않고 시간 휠로 고른다.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var systemScheme

    @State private var draft: SalaryClockCore.Settings = SettingsStore.shared.settings
    @State private var confirmReset = false
    /// 숫자 키패드에는 리턴 키가 없다. 키보드 위 "완료" 버튼이 이 값을 비워 닫는다.
    @FocusState private var focused: Bool
    /// 시트가 열린 시각. 미리보기 페이스가 body가 다시 계산될 때마다 새로
    /// 그려지지 않게 한 번 얼려 둔다 — 맥 SettingsView의 panelNow와 같다.
    @State private var panelNow = currentMillis()

    private var effectiveScheme: ColorScheme {
        guard SettingsStore.shared.hasStored else { return systemScheme }
        return draft.theme == .dark ? .dark : .light
    }

    private var theme: Theme { Theme(scheme: effectiveScheme) }
    private var isValid: Bool { SettingsStore.isValid(draft) }

    /// 편집 중인 값이 아직 유효하지 않으면 저장된 설정으로 미리보기를 그린다.
    private var previewSettings: SalaryClockCore.Settings {
        isValid ? draft : SettingsStore.shared.settings
    }

    var body: some View {
        NavigationStack {
            Form {
                clockSection
                paySection
                hoursSection
                lunchSection
                workDaysSection
                resetSection
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        SettingsStore.shared.settings = draft
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") { focused = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .environment(\.colorScheme, effectiveScheme)
        .preferredColorScheme(effectiveScheme)
    }

    // MARK: - 시계

    private var clockSection: some View {
        Section("시계 페이스") {
            ClockStylePickerView(
                value: $draft.clockStyle, now: panelNow,
                shift: resolveShift(previewSettings, panelNow), theme: theme
            )
            .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            Toggle("12시간제로 보기 (오전/오후)", isOn: $draft.hour12)
        }
    }

    // MARK: - 급여

    private var paySection: some View {
        Section {
            Picker("급여 종류", selection: $draft.payMode) {
                Text("연봉").tag(PayMode.annual)
                Text("월급").tag(PayMode.monthly)
                Text("시급").tag(PayMode.hourly)
            }
            .pickerStyle(.segmented)

            HStack {
                TextField("금액", value: $draft.payAmount, format: .number)
                    .keyboardType(.numberPad)
                    .focused($focused)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                Text("원").foregroundStyle(.secondary)
            }

            Toggle("실수령액 기준으로 보기", isOn: $draft.netPay)

            if draft.netPay {
                LabeledContent("적용 공제율") {
                    Text("−\(String(format: "%.1f", effectiveRate * 100))%")
                        .monospacedDigit()
                }
                HStack {
                    Text("직접 입력")
                    TextField(
                        String(format: "%.1f", estimatedDeductions.rate * 100),
                        text: deductionRateBinding
                    )
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .multilineTextAlignment(.trailing)
                    Text("%").foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("급여")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatKoreanUnits(draft.payAmount))
                if draft.netPay {
                    Text("비워두면 추정치를 씁니다. 명세서의 공제 합계 ÷ 세전 금액")
                }
            }
        }
    }

    /// 지금 이 설정으로 계산한 월 세전 환산액 — 공제율 추정치의 기준.
    private var previewGross: Double {
        let s = previewSettings
        return monthlyGross(s, resolveShift(s, panelNow), effectiveWorkDays(s, panelNow))
    }

    private var estimatedDeductions: Deductions { estimateDeductions(previewGross) }
    private var effectiveRate: Double { draft.deductionRate ?? estimatedDeductions.rate }

    /// 비우면 nil(추정치), 숫자를 넣으면 그 값 — 맥 SettingsView와 같은 해석.
    private var deductionRateBinding: Binding<String> {
        Binding(
            get: { deductionRateText(draft.deductionRate) },
            set: { newValue in
                switch parseDeductionRateInput(newValue) {
                case .useEstimate: draft.deductionRate = nil
                case .rate(let r): draft.deductionRate = r
                case .ignore: break
                }
            }
        )
    }

    // MARK: - 근무 시간

    private var hoursSection: some View {
        Section("근무 시간") {
            DatePicker("출근", selection: timeBinding($draft.workStart), displayedComponents: .hourAndMinute)
            DatePicker("퇴근", selection: timeBinding($draft.workEnd), displayedComponents: .hourAndMinute)
        }
    }

    private var lunchSection: some View {
        Section {
            Toggle("점심시간 제외", isOn: $draft.lunchEnabled)
            if draft.lunchEnabled {
                DatePicker("시작", selection: timeBinding($draft.lunchStart), displayedComponents: .hourAndMinute)
                DatePicker("종료", selection: timeBinding(lunchEndBinding), displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("점심")
        } footer: {
            if draft.lunchEnabled { Text("무급 \(draft.lunchMinutes)분") }
        }
    }

    /// 점심은 시작~종료로 입력받고 시작+무급 분으로 저장한다 — 맥과 같은 구조.
    private var lunchEndBinding: Binding<String> {
        Binding(
            get: { lunchEndTime(start: draft.lunchStart, minutes: draft.lunchMinutes) },
            set: { newValue in
                guard let minutes = lunchMinutesFromEnd(start: draft.lunchStart, end: newValue) else { return }
                draft.lunchMinutes = minutes
            }
        )
    }

    /// 저장 형식("HH:mm")은 그대로 두고 화면에서만 Date로 바꿔 시간 휠에 넘긴다.
    /// 날짜 부분은 의미가 없으므로 오늘로 둔다.
    private func timeBinding(_ value: Binding<String>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = parseHHmm(value.wrappedValue) ?? 0
                return Calendar.current.date(
                    bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()
                ) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                value.wrappedValue = String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
            }
        )
    }

    // MARK: - 근무일수

    private var workDaysSection: some View {
        Section {
            HStack {
                Text("월 근무일수")
                TextField("", value: workDaysBinding, format: .number)
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                Text("일").foregroundStyle(.secondary)
            }
            NavigationLink("달력에서 고르기") {
                WorkdayCalendarPage(draft: $draft)
            }
            if draft.workDaysMode != .auto {
                Button("자동 \(String(workdayInfo(panelNow).workdays))일로 되돌리기") {
                    draft.workDaysMode = .auto
                }
            }
        } header: {
            Text("근무일수")
        } footer: {
            Text(workDaysHint)
        }
    }

    /// 보여주는 값은 지금 모드로 계산한 근무일수다. 고치면 manual로 넘어간다.
    private var workDaysBinding: Binding<Double> {
        Binding(
            get: { effectiveWorkDays(draft, panelNow) },
            set: { newValue in
                draft.workDaysMode = .manual
                draft.workDaysPerMonth = newValue
            }
        )
    }

    /// 웹 SettingsPanel·맥 SettingsView와 같은 안내 문구.
    private var workDaysHint: String {
        switch draft.workDaysMode {
        case .auto:
            let info = workdayInfo(panelNow)
            return info.hasHolidayData
                ? "평일 \(info.weekdays)일 − 공휴일 \(info.holidays)일. 달이 바뀌면 따라갑니다"
                : "평일 \(info.weekdays)일. 이 해의 공휴일 자료가 없어 주말만 뺐습니다"
        case .calendar: return "달력에서 고른 날로 셉니다"
        case .manual: return "직접 입력한 값으로 고정됩니다"
        }
    }

    // MARK: - 초기화

    private var resetSection: some View {
        Section {
            Button("설정 초기화", role: .destructive) { confirmReset = true }
                .confirmationDialog("모든 설정을 기본값으로 되돌릴까요?", isPresented: $confirmReset, titleVisibility: .visible) {
                    Button("초기화", role: .destructive) {
                        // 웹 resetSettings처럼 저장소에서 지운다 — 테마가 다시
                        // 기기 설정을 따라가게 된다. 시트는 연 채로 둔다.
                        SettingsStore.shared.reset()
                        draft = SettingsStore.shared.settings
                    }
                }
        } footer: {
            if !isValid {
                Text("설정값이 올바르지 않습니다. 퇴근이 출근보다 늦고, 점심시간이 근무 시간 안에 있어야 합니다.")
                    .foregroundStyle(.red)
            }
        }
    }
}

private func currentMillis() -> Int {
    Int((Date().timeIntervalSince1970 * 1000).rounded())
}
