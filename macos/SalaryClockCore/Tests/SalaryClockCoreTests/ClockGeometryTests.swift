import Testing
import Foundation
@testable import SalaryClockCore

struct ClockGolden: Decodable {
    struct Hands: Decodable {
        struct Expected: Decodable { let hour: Double; let minute: Double; let second: Double }
        let at: [Int]
        let expected: Expected
    }
    struct Dial: Decodable { let at: [Int]; let expected: Double }
    struct ArcCase: Decodable {
        struct Expected: Decodable { let startDeg: Double; let sweepDeg: Double }
        let label: String
        let settings: String
        let at: [Int]
        let expected: Expected
    }
    let hands: [Hands]
    let dial: [Dial]
    let arcs: [ArcCase]
}

@Test("골든 — clock")
func goldenClock() throws {
    let g: ClockGolden = try Golden.decode("clock.json", as: ClockGolden.self)
    let settings: [String: Settings] = try Golden.decode("settings.json", as: [String: Settings].self)
    #expect(g.hands.count > 0)

    for h in g.hands {
        let got = handAngles(Golden.ms(h.at))
        expectClose(got.hour, h.expected.hour, "hour \(h.at)")
        expectClose(got.minute, h.expected.minute, "minute \(h.at)")
        expectClose(got.second, h.expected.second, "second \(h.at)")
    }
    for d in g.dial {
        expectClose(dialAngle(Golden.ms(d.at)), d.expected, "dialAngle \(d.at)")
    }
    for a in g.arcs {
        let s = try #require(settings[a.settings])
        let sh = resolveShift(s, Golden.ms(a.at))
        let got = arcBetween(sh.startMs, sh.endMs)
        expectClose(got.startDeg, a.expected.startDeg, "\(a.label) startDeg")
        expectClose(got.sweepDeg, a.expected.sweepDeg, "\(a.label) sweepDeg")
    }
}

@Test("초침은 밀리초를 버리지 않는다 — 스위프 운동의 전부다")
func secondHandSweeps() {
    let a = handAngles(Golden.ms([2026, 8, 22, 0, 0, 0, 0]))
    let b = handAngles(Golden.ms([2026, 8, 22, 0, 0, 0, 500]))
    #expect(a.second == 0)
    expectClose(b.second, 3, "0.5초 = 3도")
}

@Test("DST로 하루가 25시간인 날에도 바늘은 벽시계를 따른다")
func handsFollowWallClockAcrossDST() {
    // 2026-11-01은 미국 서머타임 해제일이다. 14:00은 자정에서 실제로 15시간
    // 지난 시점이지만 벽시계는 14시를 가리킨다. 경과 시간으로 계산하면 90도,
    // 벽시계로 계산하면 60도가 나온다.
    let h = handAngles(Golden.ms([2026, 10, 1, 14, 0, 0]))
    expectClose(h.hour, 60, "시침")
    expectClose(h.minute, 0, "분침")
    expectClose(h.second, 0, "초침")
}

@Test("시프트가 없으면 빈 호를 돌려준다")
func emptyArcsWhenNoShift() {
    let arcs = shiftArcs(nil, Golden.ms([2026, 8, 26, 14, 0, 0]))
    #expect(arcs.work.sweepDeg == 0)
    #expect(arcs.progress.sweepDeg == 0)
    #expect(arcs.lunch == nil)
}
