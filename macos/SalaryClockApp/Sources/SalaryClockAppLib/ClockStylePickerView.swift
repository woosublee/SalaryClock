import SwiftUI
import SalaryClockCore

/// 시계 페이스를 고른다 — 웹 components/ClockStylePicker.tsx.
///
/// 이름만 나열하면 고를 수가 없다. 페이스를 실제로 그려서 보여준다.
/// 시각을 고정해서 받으므로 미리보기 열 개가 초당 몇십 번 다시 그려지지 않는다.
///
/// 페이스가 늘어나도 아래로 흐르지 않고 한 줄에서 좌우로 넘긴다. 설정 창은
/// 위아래로 이미 길어서, 여기까지 세로로 쌓이면 다른 항목이 창 밖으로 밀린다.
struct ClockStylePickerView: View {
    @Binding var value: String
    let now: Int
    let shift: Shift?
    let theme: Theme

    /// 칸 하나의 폭과 칸 사이 간격 — 웹의 `w-[4.5rem]`과 `gap-2`.
    private static let itemWidth: CGFloat = 72
    private static let spacing: CGFloat = 8
    private static var stride: CGFloat { itemWidth + spacing }

    @State private var hovered: ClockStyle?
    @State private var hoveredArrow: Int?
    /// 지금 왼쪽 끝에 와 있는 칸. 화살표로 옮길 때도, 사용자가 트랙패드로
    /// 밀 때도 같은 값이 갱신되므로 화살표를 언제 감출지 이 하나로 정한다.
    @State private var leading: ClockStyle?
    /// 한 번에 보이는 칸 수. 창 폭에서 재야 "한 화면만큼 넘기기"와 "끝에
    /// 닿았는지"를 둘 다 알 수 있다.
    @State private var visibleCount = 1

    private var styles: [ClockStyle] { ClockStyle.allCases }
    private var leadingIndex: Int {
        leading.flatMap { styles.firstIndex(of: $0) } ?? 0
    }
    private var atStart: Bool { leadingIndex == 0 }
    private var atEnd: Bool { leadingIndex + visibleCount >= styles.count }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Self.spacing) {
                ForEach(styles, id: \.self) { item($0) }
            }
            // 선택 테두리가 스크롤 영역 가장자리에서 잘리지 않게 한 겹 띄운다
            .padding(1)
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        // 웹의 `snap-x snap-mandatory` + `snap-start`에 해당한다 — 칸이
        // 반쯤 걸친 채로 멈추지 않는다.
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $leading)
        .background {
            // 폭을 재기만 하고 그리지는 않는다. 화살표 한 번에 몇 칸을
            // 넘길지와, 끝에 닿았는지를 여기서 안다.
            GeometryReader { geo in
                Color.clear.onChange(of: geo.size.width, initial: true) { _, width in
                    visibleCount = max(1, Int((width + Self.spacing) / Self.stride))
                }
            }
        }
        .overlay(alignment: .leading) { arrow(-1) }
        .overlay(alignment: .trailing) { arrow(1) }
    }

    /// 웹은 끝에 닿으면 화살표를 `opacity-0`으로 숨기고 클릭도 막는다.
    /// 자리를 비우지 않고 투명하게만 두는 쪽이 칸 폭이 흔들리지 않는다.
    @ViewBuilder
    private func arrow(_ direction: Int) -> some View {
        let disabled = direction < 0 ? atStart : atEnd
        Button {
            page(direction)
        } label: {
            Image(systemName: direction > 0 ? "chevron.right" : "chevron.left")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(
                    hoveredArrow == direction
                        ? theme.iconButtonHover
                        : theme.pair(Palette.slate500, Palette.slate300)
                )
                .frame(width: 20, height: 20)
                .background(
                    Circle().fill(theme.pair(Palette.white, Palette.slate800))
                )
                .overlay(
                    Circle().strokeBorder(
                        theme.pair(Palette.slate200, Palette.slate600), lineWidth: 1
                    )
                )
                .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(direction > 0 ? "다음 시계" : "이전 시계")
        .offset(x: direction > 0 ? 1 : -1)
        .opacity(disabled ? 0 : 1)
        .allowsHitTesting(!disabled)
        .onHover { hoveredArrow = $0 ? direction : (hoveredArrow == direction ? nil : hoveredArrow) }
    }

    /// 한 화면에서 한 칸을 뺀 만큼 넘긴다 — 경계에 걸친 페이스가 다음 화면의
    /// 첫 칸으로 이어져 흐름이 끊기지 않는다. 웹이 `clientWidth * 0.8`만큼
    /// 미는 것과 같은 의도다.
    private func page(_ direction: Int) {
        let step = max(1, visibleCount - 1) * direction
        // 끝에서는 마지막 칸이 오른쪽에 닿는 자리까지만 간다. 그 너머로
        // 보내면 빈자리가 남고 atEnd 판정과도 어긋난다.
        let limit = max(0, styles.count - visibleCount)
        let next = min(max(leadingIndex + step, 0), limit)
        withAnimation(.easeInOut(duration: 0.2)) {
            leading = styles[next]
        }
    }

    private func item(_ style: ClockStyle) -> some View {
        let selected = style.rawValue == value
        return Button {
            value = style.rawValue
        } label: {
            VStack(spacing: 4) {
                ClockFaceView(style: style, now: now, shift: shift, theme: theme)
                    .frame(width: 48, height: 48)
                Text(style.label)
                    .font(.system(size: 11, weight: selected ? .medium : .regular))
                    .foregroundStyle(
                        selected
                            ? theme.pair(Palette.emerald700, Palette.emerald300)
                            : theme.secondary
                    )
                    .lineLimit(1)
            }
            .padding(8)
            .frame(width: Self.itemWidth)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected
                        ? theme.pair(Palette.emerald50, Palette.emerald950.opacity(0.4))
                        : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(border(style, selected: selected), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? style : (hovered == style ? nil : hovered) }
    }

    private func border(_ style: ClockStyle, selected: Bool) -> Color {
        if selected { return Palette.emerald500 }
        return hovered == style
            ? theme.pair(Palette.slate300, Palette.slate600)
            : theme.pair(Palette.slate200, Palette.slate700)
    }
}
