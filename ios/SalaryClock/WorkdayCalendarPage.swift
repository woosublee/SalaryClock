import SwiftUI
import SalaryClockCore

/// 근무일을 날짜별로 찍는 화면 — 웹 components/MonthCalendar.tsx와 같은 기능을
/// 손가락 크기에 맞게 다시 그렸다. 칸 분류(monthCells)와 색(Theme)은 맥·웹과 같다.
///
/// Form 안에 두지 않는다. Form은 한 줄 안의 버튼을 한 덩어리로 다뤄서, 날짜
/// 칸 수십 개가 한 줄에 들어가면 누른 칸이 아닌 다른 칸이 눌리기 쉽다.
struct WorkdayCalendarPage: View {
    @Binding var draft: SalaryClockCore.Settings
    @State private var year = thisMonth().year
    @State private var month = thisMonth().month

    @Environment(\.colorScheme) private var scheme
    private var theme: Theme { Theme(scheme: scheme) }

    private static let dowLabels = ["일", "월", "화", "수", "목", "금", "토"]
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var cells: [DayCell] { monthCells(year, month, draft.dayOverrides) }
    private var workdays: Int { cells.filter(\.isWorkday).count }
    private var isThisMonth: Bool { (year, month) == thisMonth() }
    /// 이 달에 찍어 둔 날이 있는지. 없으면 지우기를 누를 이유가 없다.
    private var hasOverridesThisMonth: Bool {
        clearMonthOverrides(draft.dayOverrides, year, month).count != draft.dayOverrides.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                actions
                grid
                legend
                Text("날짜를 누르면 근무일과 쉬는 날이 바뀝니다. 설정에서 저장을 눌러야 반영됩니다.")
                    .font(.footnote)
                    .foregroundStyle(theme.dim)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("근무일 달력")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: draft.dayOverrides)
    }

    private var header: some View {
        HStack {
            monthArrow("chevron.left", delta: -1, label: "이전 달")
            Spacer()
            VStack(spacing: 2) {
                // verbatim — 보간을 LocalizedStringKey로 넘기면 연도에 쉼표가 붙는다.
                Text(verbatim: "\(year)년 \(month + 1)월")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.foreground)
                Text(verbatim: "근무 \(workdays)일")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(theme.calendarHeaderText)
            }
            Spacer()
            monthArrow("chevron.right", delta: 1, label: "다음 달")
        }
    }

    private func monthArrow(_ symbol: String, delta: Int, label: String) -> some View {
        Button {
            (year, month) = stepMonth(year, month, delta)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .foregroundStyle(theme.calendarHeaderText)
        .accessibilityLabel(label)
    }

    private var actions: some View {
        HStack {
            if !isThisMonth {
                Button("이번 달") { (year, month) = thisMonth() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            Spacer()
            Button("이 달 선택 지우기") {
                draft.dayOverrides = clearMonthOverrides(draft.dayOverrides, year, month)
            }
            .font(.subheadline)
            .foregroundStyle(hasOverridesThisMonth ? theme.calendarHeaderText : theme.dim.opacity(0.5))
            .disabled(!hasOverridesThisMonth)
        }
        .frame(minHeight: 32)
    }

    private var grid: some View {
        LazyVGrid(columns: Self.columns, spacing: 6) {
            ForEach(Array(Self.dowLabels.enumerated()), id: \.offset) { dow, label in
                Text(label)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(theme.calendarDowLabel(dow))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 2)
            }
            ForEach(0..<(cells.first?.dow ?? 0), id: \.self) { _ in
                Color.clear.aspectRatio(1, contentMode: .fit)
            }
            ForEach(cells, id: \.date) { cell in
                dayButton(cell)
            }
        }
    }

    private func dayButton(_ cell: DayCell) -> some View {
        Button {
            // 웹과 같다 — 날짜를 찍으면 근무일수가 달력 기준으로 넘어간다.
            draft.workDaysMode = .calendar
            draft.dayOverrides = toggleOverride(draft.dayOverrides, cell.date)
        } label: {
            Text(verbatim: "\(cell.day)")
                .font(.system(size: 17, weight: theme.calendarBold(for: cell.kind) ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(theme.calendarForeground(for: cell.kind))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(theme.calendarBackground(for: cell.kind))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(month + 1)월 \(cell.day)일 \(cell.isWorkday ? "근무" : "휴무")")
        .accessibilityAddTraits(cell.isWorkday ? [] : .isSelected)
    }

    private var legend: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
            legendItem(.weekend, "주말")
            legendItem(.holiday, "공휴일")
            legendItem(.customOff, "내가 쉰 날")
            legendItem(.customWork, "쉬는날 출근")
        }
    }

    private func legendItem(_ kind: DayKind, _ label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(theme.calendarBackground(for: kind))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.badgeBorder, lineWidth: 0.5))
                .frame(width: 14, height: 14)
            Text(label)
                .font(.footnote)
                .foregroundStyle(theme.dim)
        }
    }
}

/// 지금 이 순간의 (연, 0-based 월). 맥 SettingsView의 calendarComponents와 같은 규칙.
private func thisMonth() -> (year: Int, month: Int) {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone.current
    let now = Date()
    return (cal.component(.year, from: now), cal.component(.month, from: now) - 1)
}
