import SwiftUI
import SalaryClockCore

/// 시계 화면과 설정 시트를 묶는다. 맥의 AppDelegate가 하던 일 중 iOS에 남는
/// 것은 tick 하나뿐이다 — 메뉴바도, 갱신 주기 조절도 없다.
struct RootView: View {
    @State private var model = TickModel()
    @State private var showSettings = false
    /// 기기 설정 — 저장된 테마가 없을 때만 쓴다.
    @Environment(\.colorScheme) private var systemScheme

    /// PopoverView와 같은 세 상태 규칙. 화면 가장자리(안전 영역 바깥)까지
    /// 같은 바탕색을 깔려면 여기서도 알아야 한다.
    private var effectiveScheme: ColorScheme {
        guard SettingsStore.shared.hasStored else { return systemScheme }
        return model.settings.theme == .dark ? .dark : .light
    }

    private var theme: Theme { Theme(scheme: effectiveScheme) }

    var body: some View {
        GeometryReader { geo in
            // 팝오버(220×400쯤)를 화면에 들어가는 만큼 키운다. 아이패드에서
            // 끝없이 커지지 않게 두 배에서 멈춘다.
            let scale = min(geo.size.width / 220, geo.size.height / 400, 2)
            PopoverView(
                model: model,
                onSettings: { showSettings = true },
                scale: scale
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.background.ignoresSafeArea())
        .sheet(isPresented: $showSettings) {
            ScrollView {
                SettingsView(onDone: { showSettings = false })
            }
            .scrollDismissesKeyboard(.interactively)
            .background(theme.background.ignoresSafeArea())
        }
        // 화면에 있는 동안만 돈다. 앱이 백그라운드로 가면 iOS가 멈추고, 돌아오면
        // 매 tick이 지금 시각으로 다시 계산하므로 따로 맞출 것이 없다.
        .task {
            while !Task.isCancelled {
                tick()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func tick() {
        let now = Int((Date().timeIntervalSince1970 * 1000).rounded())
        let s = SettingsStore.shared.settings
        model.now = now
        model.earnings = computeEarnings(s, now)
        model.settings = s
    }
}
