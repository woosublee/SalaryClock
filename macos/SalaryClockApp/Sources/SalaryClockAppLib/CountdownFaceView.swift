import SwiftUI
import SalaryClockCore

/// 남은 — 다른 페이스들이 "얼마나 쌓였나"를 그린다면, 이건 "얼마나 남았나"를
/// 그린다. 웹 components/clock/CountdownFace.tsx.
///
/// 호가 차오르는 게 아니라 퇴근 쪽으로 줄어든다. 같은 시간을 반대편에서 보는
/// 것뿐인데 하루의 체감이 완전히 달라져서 페이스 하나를 따로 뒀다.
/// 색도 쌓임(에메랄드)과 구분해 호박색을 쓴다.
struct CountdownFaceView: View {
    let now: Int
    let shift: Shift?
    let theme: Theme

    private let ringR: CGFloat = 92
    private let dialR: CGFloat = 74

    var body: some View {
        faceCanvas { ctx in
            let arcs = shiftArcs(shift, now)
            let hands = handAngles(now)
            let center = CGPoint(x: faceCX, y: faceCY)
            let amber = Palette.amber500

            let remaining: Arc = {
                guard let shift else { return Arc(startDeg: 0, sweepDeg: 0) }
                return arcBetween(min(max(now, shift.startMs), shift.endMs), shift.endMs)
            }()

            // 지나간 구간은 흔적만, 남은 구간은 굵게
            ctx.strokeArc(
                arcs.work, radius: ringR, width: 2,
                color: theme.pair(Palette.slate200, Palette.slate800), cap: .butt
            )
            ctx.strokeArc(remaining, radius: ringR, width: 7, color: amber)
            if let lunch = arcs.lunch {
                // 남은 구간 안의 점심은 파낸다
                ctx.strokeArc(lunch, radius: ringR, width: 11, color: theme.background, cap: .butt)
            }

            // 퇴근 지점 표식. 근무가 없는 날은 arcs.work가 0이라 12시 자리에
            // 점이 찍히므로, 시프트가 없으면 아예 그리지 않는다.
            if shift != nil {
                ctx.fillCircle(
                    facePolar(ringR, arcs.work.startDeg + arcs.work.sweepDeg), 4,
                    theme.pair(Palette.amber600, Palette.amber400)
                )
            }

            let tickColor = theme.pair(Palette.slate300, Palette.slate600)
            for i in 0..<12 {
                let deg = Double(i) * 30
                let long = i % 3 == 0
                ctx.strokeLine(
                    from: facePolar(dialR, deg), to: facePolar(dialR - (long ? 10 : 4), deg),
                    width: long ? 2.5 : 1, color: tickColor, cap: .round
                )
            }

            ctx.strokeHand(angle: hands.hour, from: 9, to: -40, width: 5, color: theme.hands)
            ctx.strokeHand(angle: hands.minute, from: 11, to: -60, width: 3, color: theme.hands)
            ctx.strokeHand(angle: hands.second, from: 14, to: -66, width: 1.25, color: amber)
            ctx.fillCircle(center, 3.5, amber)
        }
    }
}
