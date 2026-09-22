import SwiftUI
import SalaryClockCore

/// 웹 `components/MonthCalendar.tsx`를 옮긴 것.
///
/// 7열 그리드, 1일의 요일만큼 앞을 비우고, 칸 색은 kind로 가른다. 월 이동은
/// 이 뷰의 밖(SettingsView)에서 year/month를 바꿔 다시 그리는 방식으로 한다 —
/// 이 뷰 자체는 순수하게 "이 달을 그린다"만 안다.
struct MonthCalendarView: View {
    let year: Int
    /// 0-based
    let month: Int
    let overrides: [String]
    var onToggle: (String) -> Void
    var onClearMonth: () -> Void

    @Environment(\.colorScheme) private var scheme
    private var theme: Theme { Theme(scheme: scheme) }

    private static let dowLabels = ["일", "월", "화", "수", "목", "금", "토"]
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var cells: [DayCell] { monthCells(year, month, overrides) }
    private var workdays: Int { cells.filter(\.isWorkday).count }
    /// 1일이 무슨 요일인지에 맞춰 앞을 비운다
    private var leading: Int { cells.first?.dow ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            grid
            legend
        }
        .padding(12)
        .background(theme.calendarPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var header: some View {
        HStack {
            // Text("\(year)년 ...")는 LocalizedStringKey 보간을 타면서 연도 같은
            // 4자리 Int에 천 단위 구분 쉼표를 몰래 붙인다("2,026년") — verbatim으로
            // 이미 만든 String을 그대로 보여줘야 웹과 같은 글자가 나온다.
            Text(verbatim: "\(year)년 \(month + 1)월 · 근무 \(workdays)일")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.calendarHeaderText)
            Spacer()
            Button("이 달 선택 지우기", action: onClearMonth)
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .underline()
                .foregroundStyle(theme.calendarClearButton)
        }
    }

    private var grid: some View {
        LazyVGrid(columns: Self.columns, spacing: 4) {
            ForEach(Array(Self.dowLabels.enumerated()), id: \.offset) { dow, label in
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.calendarDowLabel(dow))
                    .frame(maxWidth: .infinity)
            }

            ForEach(0..<leading, id: \.self) { _ in
                Color.clear.aspectRatio(1, contentMode: .fit)
            }

            ForEach(cells, id: \.date) { cell in
                dayButton(cell)
            }
        }
    }

    private func dayButton(_ cell: DayCell) -> some View {
        Button {
            onToggle(cell.date)
        } label: {
            Text(verbatim: "\(cell.day)")
                .font(.system(size: 11, weight: theme.calendarBold(for: cell.kind) ? .medium : .regular))
                .monospacedDigit()
                .foregroundStyle(theme.calendarForeground(for: cell.kind))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(theme.calendarBackground(for: cell.kind))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(month + 1)월 \(cell.day)일 \(cell.isWorkday ? "근무" : "휴무")")
    }

    private var legend: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 4) {
            legendItem(kind: .weekend, label: "주말")
            legendItem(kind: .holiday, label: "공휴일")
            legendItem(kind: .customOff, label: "내가 쉰 날")
            legendItem(kind: .customWork, label: "쉬는날 출근")
        }
    }

    private func legendItem(kind: DayKind, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.calendarBackground(for: kind))
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(theme.dim)
        }
    }
}
