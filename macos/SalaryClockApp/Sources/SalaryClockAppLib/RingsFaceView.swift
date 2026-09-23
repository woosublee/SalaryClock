import SwiftUI
import SalaryClockCore

/// 고리 — 바늘이 없다. 웹 components/clock/RingsFace.tsx.
///
/// 다른 얼굴은 문자판 위 위치로 시각을 읽지만, 여기서는 네 개의 호가
/// 각각 12시에서 출발해 자란 길이로 읽는다. 바깥이 하루 진행이고,
/// 안으로 들어올수록 시·분·초로 빨라진다. 초 고리가 1분마다 감겼다 풀리는
/// 게 이 얼굴의 움직임 전부다.
struct RingsFaceView: View {
    let now: Int
    let shift: Shift?
    let theme: Theme

    private let rProgress: CGFloat = 92
    private let rHour: CGFloat = 74
    private let rMinute: CGFloat = 60
    private let rSecond: CGFloat = 46

    var body: some View {
        faceCanvas { ctx in
            let hands = handAngles(now)
            let progress: Double = {
                guard let shift, shift.paidMs != 0 else { return 0 }
                return Double(paidMsBetween(shift, shift.startMs, now)) / Double(shift.paidMs)
            }()

            let track = theme.pair(Palette.slate100, Palette.slate800)
            func ring(_ r: CGFloat, _ sweepDeg: Double, _ tone: Color, _ width: CGFloat) {
                ctx.strokeCircle(CGPoint(x: faceCX, y: faceCY), r, width: width, color: track)
                ctx.strokeArc(
                    startDeg: 0, sweepDeg: sweepDeg,
                    radius: r, width: width, color: tone
                )
            }

            ring(rProgress, progress * 360, theme.accent, 6)
            ring(rHour, hands.hour, theme.pair(Palette.slate500, Palette.slate300), 4)
            ring(rMinute, hands.minute, Palette.slate400, 3)
            ring(rSecond, hands.second, Palette.emerald400, 2)

            // 12시 기준선. 네 고리가 모두 여기서 출발한다는 걸 알려준다
            ctx.strokeLine(
                from: CGPoint(x: faceCX, y: faceCY - rProgress - 4),
                to: CGPoint(x: faceCX, y: faceCY - rSecond + 4),
                width: 0.75, color: theme.pair(Palette.slate300, Palette.slate700)
            )
        }
    }
}
