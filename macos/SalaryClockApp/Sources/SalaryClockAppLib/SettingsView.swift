import SwiftUI
import ServiceManagement
import SalaryClockCore

/// 지금 이 순간의 (연, 월) — 달력 모드가 처음 열릴 때 보여줄 달.
/// SalaryClockCore의 `appCalendar`는 core 모듈 내부에만 보이므로(internal)
/// 여기서 같은 규칙(그레고리력 고정, 기기 시간대)으로 새로 만든다.
/// month는 0-based로 맞춘다.
private func calendarComponents() -> (year: Int, month: Int) {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone.current
    let now = Date()
    return (cal.component(.year, from: now), cal.component(.month, from: now) - 1)
}

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
    /// 승인 대기(.requiresApproval)도 켠 것으로 본다 — 사용자는 켜겠다고 했고,
    /// 남은 일은 시스템 설정에서 허용하는 것뿐이다. 그 사실은 아래 안내가 알린다.
    @State private var launchAtLogin: Bool = Self.loginItemOn(SMAppService.mainApp.status)
    @State private var loginItemStatus: SMAppService.Status = SMAppService.mainApp.status
    // 공제율 직접 입력 섹션을 펼쳤는지 — 웹 SettingsPanel의 showAdvanced와 같다.
    @State private var showAdvanced = false
    /// 초기화가 두 번째 누름을 기다리는 중인지 — 웹 `resetArmed`와 같다.
    @State private var resetArmed = false
    @State private var disarmTask: Task<Void, Never>?
    // 달력이 보여주는 달. 창을 열 때는 이번 달에서 시작하고 화살표로 옮긴다.
    // 웹 SettingsPanel도 같다 — 다음 달 연차를 미리 찍어 둘 수 있어야 한다.
    @State private var calendarYear = calendarComponents().year
    @State private var calendarMonth = calendarComponents().month
    // 달력을 펼쳤는지 — Settings에 안 담기는 순수 뷰 상태다. 웹 SettingsPanel의
    // showCalendar와 같다. 저장하지 않는다.
    @State private var showCalendar = false
    /// 메뉴바 갱신 주기 입력칸의 원문. 숫자로 못 읽는 값도 그대로 담아 두고
    /// 빨갛게 보여줘야 하므로(다른 시각 입력칸과 같은 규칙) Double이 아니라
    /// String으로 갖는다.
    @State private var intervalText = SettingsView.formatInterval(AppPreferences.shared.menuBarInterval)
    /// 업데이트 자동 확인. 값은 Sparkle이 자기 UserDefaults 키에 담으므로
    /// 저장 버튼을 기다리지 않고 토글하는 즉시 반영한다 — draft에 담지 않는
    /// 이유이기도 하다.
    @State private var automaticDownloads = UpdaterController.shared.automaticallyDownloads
    @ObservedObject private var updater = UpdaterController.shared
    /// 창이 열린 시각. 웹 SettingsPanel의 `panelNow`와 같다 —
    /// `const [panelNow] = useState(now)`로 한 번 얼려 두고 창이 닫힐 때까지
    /// 그 값을 쓴다. 미리보기 페이스 열 개가 body가 다시 계산될 때마다 새 시각으로
    /// 다시 그려지지 않게 하려면 여기가 고정이어야 한다.
    @State private var panelNow = Int((Date().timeIntervalSince1970 * 1000).rounded())
    /// 기기 설정 — 저장된 테마가 없을 때만 쓴다.
    @Environment(\.colorScheme) private var systemScheme

    /// 웹 `loadSettings`와 같은 세 상태 규칙: 저장된 값이 없으면(hasStored ==
    /// false) 기기 설정을 따르고, 한 번이라도 저장했으면 그 값에 고정한다.
    /// 테마를 고르는 토글 자체는 팝오버에만 있으므로, 여기서는 draft.theme을
    /// 그대로 읽기만 한다.
    private var effectiveScheme: ColorScheme {
        guard SettingsStore.shared.hasStored else { return systemScheme }
        return draft.theme == .dark ? .dark : .light
    }

    private var theme: Theme { Theme(scheme: effectiveScheme) }

    /// 달력이 이번 달을 보고 있는지. 아니면 "이번 달" 단추를 띄운다.
    ///
    /// 창이 열린 시각(panelNow)이 아니라 지금 시각으로 판단한다 — 창을 자정
    /// 직전에 열어 두면 달이 넘어가는데, 그때 이번 달이 아닌 화면을 이번 달이라고
    /// 우기지 않는다.
    private var isThisMonth: Bool {
        let now = calendarComponents()
        return calendarYear == now.year && calendarMonth == now.month
    }

    /// 미리보기에 쓸 시프트. 웹 `previewShift`와 같은 규칙으로, 편집 중인 값이
    /// 아직 유효하지 않으면 저장된 설정으로 그린다 — 출근 시각을 지우는 도중에
    /// 미리보기가 깨지지 않게.
    private var previewShift: Shift? {
        let base = SettingsStore.isValid(draft) ? draft : SettingsStore.shared.settings
        return resolveShift(base, panelNow)
    }
    private var intervalValue: Double? { Double(intervalText) }

    /// 위아래 버튼이 쓸 값. 입력칸은 문자열이라(숫자로 못 읽는 값도 그대로
    /// 담아 빨갛게 보여줘야 한다) 버튼 쪽에서만 숫자로 바꿔 쓴다.
    ///
    /// 읽을 수 없는 값이 들어 있을 때는 기본값에서 출발한다 — 버튼을 눌렀는데
    /// 아무 일도 안 일어나면 고장으로 보인다.
    private var intervalStepBinding: Binding<Double> {
        Binding(
            get: { intervalValue ?? AppPreferences.defaultInterval },
            set: { intervalText = Self.formatInterval(steppedInterval($0)) }
        )
    }
    private var intervalValid: Bool { intervalValue.map(AppPreferences.isValid) ?? false }
    private var isValid: Bool { SettingsStore.isValid(draft) && intervalValid }

    private static func formatInterval(_ v: Double) -> String { String(format: "%.1f", v) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("설정").font(.system(size: 18, weight: .bold))

            // 웹 SettingsPanel도 시계 페이스가 급여보다 앞에 온다.
            field("시계 페이스") {
                ClockStylePickerView(
                    value: $draft.clockStyle, now: panelNow,
                    shift: previewShift, theme: theme
                )
            }

            // 실수령액 토글·공제율은 웹처럼 급여 박스 안, 금액 바로 아래에 둔다 —
            // 근무시간·점심 밑으로 내려서 급여 묶음을 깨뜨리지 않는다.
            field("급여") {
                Picker("", selection: $draft.payMode) {
                    Text("연봉").tag(PayMode.annual)
                    Text("월급").tag(PayMode.monthly)
                    Text("시급").tag(PayMode.hourly)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                // 웹의 금액칸(text-xl, 오른쪽 정렬, "원" 접미사)과 같은 강조를 준다.
                // "원"이 숫자와 겹치지 않도록 필드 자체에 오른쪽 여백을 비워 두고
                // 그 자리에 접미사를 얹는다.
                TextField("", value: $draft.payAmount, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .padding(.trailing, 22)
                    .overlay(alignment: .trailing) {
                        Text("원")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.dim)
                            .padding(.trailing, 10)
                    }
                Text(formatKoreanUnits(draft.payAmount))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.dim)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Toggle("실수령액 기준으로 보기", isOn: $draft.netPay)
                // 같은 급여를 넣어도 웹과 맥이 다른 금액을 보여준 원인 중 하나가
                // 이 필드의 부재였다 — 근무일수(auto)는 웹과 같은 계산이라 문제가
                // 아니었고, 공제율을 웹은 직접 입력할 수 있는데 맥은 항상 추정치만
                // 썼다. deductionRate가 nil이면 추정치를, 있으면 그 값을 그대로
                // 쓴다 (SalaryClockCore.deductionRateFor).
                if draft.netPay {
                    deductionSection
                }
            }

            // 웹은 출근·퇴근을 각자 라벨을 단 칸으로 나란히 보여준다 — 하나의
            // "근무 시간" 헤더에 대시로 묶지 않는다.
            HStack(alignment: .top, spacing: 12) {
                field("출근") { timeField($draft.workStart) }
                field("퇴근") { timeField($draft.workEnd) }
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

            workDaysSection

            // 웹에 대응물이 없는 맥 전용 옵션 묶음. 라벨을 위에 얹지 않고
            // 한 줄에 붙여 세로 길이를 줄인다 — 위쪽 항목들과 달리 웹을 따라야
            // 할 배치가 없다.
            Toggle("로그인할 때 자동 실행", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    // 등록이 실패해도 앱은 계속 돌아야 한다. 토글만 되돌린다.
                    // register()는 오류 없이 끝나도 승인 대기일 수 있으므로
                    // 성공·실패와 상관없이 실제 상태를 다시 읽는다.
                    if on { try? SMAppService.mainApp.register() }
                    else { try? SMAppService.mainApp.unregister() }
                    refreshLoginItemStatus()
                }

            if loginItemStatus == .requiresApproval {
                HStack(spacing: 6) {
                    Text("시스템 설정에서 허용해야 자동 실행됩니다")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.dim)
                    Spacer()
                    Button("로그인 항목 열기") {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                    .font(.system(size: 11))
                }
            }

            HStack(spacing: 8) {
                Text("메뉴바 갱신").font(.system(size: 12))
                Spacer()
                TextField("", text: $intervalText)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(intervalValid ? theme.foreground : .red)
                    .frame(width: 72)
                    .padding(.trailing, 18)
                    .overlay(alignment: .trailing) {
                        Text("초")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.dim)
                            .padding(.trailing, 10)
                    }
                Stepper("", value: intervalStepBinding, in: AppPreferences.range, step: 0.1)
                    .labelsHidden()
            }
            Text("0.1~10초. 짧을수록 부드럽지만 배터리를 조금 더 씁니다")
                .font(.system(size: 10))
                .foregroundStyle(theme.dim)

            updateSection

            if !isValid {
                Text("설정값이 올바르지 않습니다")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            HStack {
                // 웹 SettingsPanel도 초기화를 바닥 왼쪽에 따로 떼어 둔다.
                Button(resetArmed ? "한 번 더 누르면 초기화" : "초기화", action: armOrReset)
                    .buttonStyle(.plain)
                    .foregroundStyle(resetArmed ? Color.red : theme.iconButton)
                Spacer()
                Button("닫기", action: onDone)
                Button("저장") {
                    SettingsStore.shared.settings = draft
                    // isValid가 true일 때만 이 버튼이 눌리므로 intervalValue는
                    // 항상 유효한 값을 담고 있다 — if let은 안전망일 뿐이다.
                    if let interval = intervalValue {
                        AppPreferences.shared.menuBarInterval = interval
                    }
                    onDone()
                }
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(theme.background)
        // preferredColorScheme만으로는 하위 뷰의 @Environment(\.colorScheme)가
        // 바뀌지 않는다. MonthCalendarView는 그 키로 Theme을 만들므로, 심어주지
        // 않으면 밝은 맥에서 어두운 테마를 골랐을 때 달력 칸만 하얗게 남는다.
        .environment(\.colorScheme, effectiveScheme)
        .preferredColorScheme(effectiveScheme)
    }

    /// 맥 전용 항목. 웹에 대응물이 없다.
    ///
    /// 자동 확인은 초기화(resetAll)가 건드리지 않는다. 다른 항목과 달리
    /// 기본값으로 되돌리는 것이 곧 "업데이트를 안 받는다"가 되어, 설정을
    /// 정리하려던 사람이 보안 수정까지 못 받게 되기 때문이다.
    @ViewBuilder
    private var updateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("업데이트")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.secondary)

            if updater.isAvailable {
                Toggle("새 버전을 자동으로 설치", isOn: $automaticDownloads)
                    .onChange(of: automaticDownloads) { _, on in
                        UpdaterController.shared.automaticallyDownloads = on
                    }
                Text("앱을 열 때와 하루에 한 번 확인합니다")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.dim)
                HStack(spacing: 8) {
                    Button("지금 확인") { UpdaterController.shared.checkForUpdates() }
                        .disabled(!updater.canCheck)
                    Spacer()
                    Text("\(versionLine) · \(lastCheckLine)")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.dim)
                }
            } else {
                // 개발 빌드다. 버튼을 눌러도 할 일이 없으므로 아예 두지 않고
                // 왜 없는지를 적는다.
                Text("개발 빌드에는 업데이트 기능이 없습니다 · \(versionLine)")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.dim)
            }
        }
        // 위쪽 항목들과 달리 이 묶음은 앱 자체에 관한 것이라 배경을 깔아
        // 떼어 놓는다.
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.pair(Palette.slate50, Palette.slate900))
        )
    }

    /// 마지막으로 확인한 시각. 자동 확인이 정말 돌고 있는지는 이 줄로만
    /// 드러난다 — 켜 두기만 하고 실제로는 안 돌던 경우를 눈으로 잡을 수 있다.
    private var lastCheckLine: String {
        guard let date = updater.lastCheck else { return "확인한 적 없음" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 HH:mm"
        return f.string(from: date)
    }

    /// "1.0.0 (빌드 3)" — 업데이트가 실제로 올라왔는지 확인할 때 이 줄을 본다.
    private var versionLine: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (빌드 \(build))"
    }

    /// 첫 누름은 무장만 하고 3초 뒤 풀린다. 그 안에 다시 누르면 초기화한다.
    /// 되돌릴 수 없는 일이라 웹 SettingsPanel과 같이 두 번 누르게 한다.
    private func armOrReset() {
        disarmTask?.cancel()
        guard resetArmed else {
            resetArmed = true
            disarmTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled { resetArmed = false }
            }
            return
        }
        resetArmed = false
        resetAll()
    }

    private static func loginItemOn(_ status: SMAppService.Status) -> Bool {
        status == .enabled || status == .requiresApproval
    }

    private func refreshLoginItemStatus() {
        loginItemStatus = SMAppService.mainApp.status
        launchAtLogin = Self.loginItemOn(loginItemStatus)
    }

    /// 설정을 기본값으로 되돌린다 — 웹 `resetSettings`에 대응한다.
    /// 패널은 연 채로 둔다. 웹도 같다.
    ///
    /// 맥에만 있는 항목까지 함께 되돌린다. 사용자에게는 전부 이 창의 항목이라
    /// 공유 설정만 되돌리면 절반만 초기화된다. 로그인 자동 실행은 저장값이
    /// 아니라 시스템 등록이지만, 이 창에서 켠 것이므로 같이 내린다.
    private func resetAll() {
        SettingsStore.shared.reset()
        AppPreferences.shared.reset()
        try? SMAppService.mainApp.unregister()

        draft = SettingsStore.shared.settings
        intervalText = Self.formatInterval(AppPreferences.shared.menuBarInterval)
        refreshLoginItemStatus()
        showAdvanced = false
        showCalendar = false
    }

    @ViewBuilder
    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(theme.secondary)
            content()
        }
    }

    /// 점심은 시작~종료 시각으로 입력받고, 저장은 무급 분(lunchStart + lunchMinutes)으로
    /// 한다 — 웹 SettingsPanel의 lunchEndValue/setLunchEnd와 같은 구조다. 실제 계산은
    /// SettingsFieldMath.swift의 순수 함수(lunchEndTime/lunchMinutesFromEnd)로 뽑아
    /// 테스트한다.
    ///
    /// 종료 시각을 읽을 때는 시작+무급분을 그대로 계산해서 보여주므로, 시작
    /// 시각을 바꾸면 무급 길이는 유지된 채 종료 시각이 따라 이동한다(값을
    /// 따로 맞춰주는 코드가 필요 없다). 종료 시각을 직접 바꾸면 그 차이만큼
    /// lunchMinutes를 다시 계산해 저장한다.
    private var lunchEndBinding: Binding<String> {
        Binding(
            get: { lunchEndTime(start: draft.lunchStart, minutes: draft.lunchMinutes) },
            set: { newValue in
                guard let minutes = lunchMinutesFromEnd(start: draft.lunchStart, end: newValue) else { return }
                draft.lunchMinutes = minutes
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
    /// 분수)으로 저장한다 — 웹 SettingsPanel의 deductionRate 입력과 같다. 해석은
    /// SettingsFieldMath.swift의 parseDeductionRateInput/deductionRateText로 뽑아
    /// 테스트한다.
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

    /// 실수령액 기준일 때만 의미가 있는 공제율 직접 입력.
    ///
    /// 웹 SettingsPanel의 같은 구간은 "공제 내역 · 직접 설정"이라 부르고
    /// 4대보험·소득세 내역 줄까지 펼친다. 맥은 공제율 칸만 옮겼으므로 라벨도
    /// 있는 것만 약속한다 — 없는 내역을 문구로 내걸지 않는다.
    private var deductionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("−\(String(format: "%.1f", effectiveRate * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.dim)
                Spacer()
                Button(showAdvanced ? "접기" : "공제율 직접 설정") {
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

    // MARK: - 근무일수

    /// 지금 시각을 epoch ms로 — auto 안내 문구와 effectiveWorkDays 계산이 쓴다.

    /// auto 기준 이번 달 근무일수 — "자동 N일로" 링크의 N.
    private var autoWorkDaysCount: Int { workdayInfo(panelNow).workdays }

    /// auto 모드 안내 — 웹 SettingsPanel의 workDaysMode === 'auto' 분기와
    /// 글자 하나까지 같다.
    private var autoWorkDaysHint: String {
        let info = workdayInfo(panelNow)
        return info.hasHolidayData
            ? "평일 \(info.weekdays)일 − 공휴일 \(info.holidays)일. 달이 바뀌면 따라갑니다"
            : "평일 \(info.weekdays)일. 이 해의 공휴일 자료가 없어 주말만 뺐습니다"
    }

    /// 웹 SettingsPanel의 "근무일수" 구간 — 모드를 직접 고르는 UI가 아니다.
    /// 숫자를 고치면 manual로, 달력에서 날짜를 찍으면 calendar로 자연히
    /// 넘어간다. "자동 N일로" 링크가 auto로 돌아가는 유일한 길이다.
    private var workDaysSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("월 근무일수")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondary)
                Spacer()
                // showCalendar는 Settings에 안 담기는 순수 뷰 상태다 — 저장하지 않는다.
                Button(showCalendar ? "달력 접기" : "달력에서 고르기") {
                    showCalendar.toggle()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .underline()
                .foregroundStyle(theme.calendarClearButton)
            }

            workDaysField
            workDaysHint

            if showCalendar {
                MonthCalendarView(
                    year: calendarYear,
                    month: calendarMonth,
                    overrides: draft.dayOverrides,
                    onToggle: { date in
                        draft.workDaysMode = .calendar
                        draft.dayOverrides = toggleOverride(draft.dayOverrides, date)
                    },
                    onClearMonth: {
                        // 지우기는 이 달의 override만 지운다 — 모드는 그대로 둔다.
                        draft.dayOverrides = clearMonthOverrides(draft.dayOverrides, calendarYear, calendarMonth)
                    },
                    onStepMonth: { delta in
                        let next = stepMonth(calendarYear, calendarMonth, delta)
                        calendarYear = next.year
                        calendarMonth = next.month
                    },
                    onToday: isThisMonth ? nil : {
                        let now = calendarComponents()
                        calendarYear = now.year
                        calendarMonth = now.month
                    }
                )
            }
        }
    }

    /// 숫자 한 칸 — 보여주는 값은 지금 모드의 effectiveWorkDays다(auto일 때도
    /// draft.workDaysPerMonth가 아니라 계산된 값을 보여준다). 고치면
    /// workDaysMode를 manual로, workDaysPerMonth를 그 값으로 한 번에 바꾼다 —
    /// 웹 입력칸의 onChange와 같다.
    private var workDaysField: some View {
        TextField("", value: workDaysBinding, format: .number)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .font(.system(size: 13, design: .monospaced))
            .padding(.trailing, 18)
            .overlay(alignment: .trailing) {
                Text("일")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.dim)
                    .padding(.trailing, 10)
            }
    }

    private var workDaysBinding: Binding<Double> {
        Binding(
            get: { effectiveWorkDays(draft, panelNow) },
            set: { newValue in
                draft.workDaysMode = .manual
                draft.workDaysPerMonth = newValue
            }
        )
    }

    /// 모드에 따라 바뀌는 안내 줄. calendar·manual은 "자동 N일로" 링크를
    /// 오른쪽에 둔다 — 누르면 workDaysMode만 auto로 돌아가고 dayOverrides는
    /// 그대로 남는다(달력을 다시 열면 찍어둔 날이 그대로 있다).
    private var workDaysHint: some View {
        Group {
            switch draft.workDaysMode {
            case .auto:
                Text(autoWorkDaysHint)
            case .calendar:
                HStack {
                    Text("달력에서 고른 날로 셉니다")
                    Spacer()
                    resetToAutoButton
                }
            case .manual:
                HStack {
                    Text("직접 입력한 값으로 고정됩니다")
                    Spacer()
                    resetToAutoButton
                }
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(theme.dim)
    }

    /// "자동 N일로" — 미리 만든 String을 그대로 넘긴다. Button(_:)에 보간
    /// 리터럴을 바로 주면 LocalizedStringKey 경로를 타면서 N에 몰래 천 단위
    /// 쉼표가 붙을 수 있다(MonthCalendarView 헤더에서 실제로 겪은 문제다).
    private var resetToAutoLabel: String { "자동 \(autoWorkDaysCount)일로" }

    private var resetToAutoButton: some View {
        Button(resetToAutoLabel) {
            draft.workDaysMode = .auto
        }
        .buttonStyle(.plain)
        .underline()
        .foregroundStyle(theme.dim)
    }
}
