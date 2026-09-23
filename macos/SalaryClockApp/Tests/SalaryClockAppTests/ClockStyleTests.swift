import Testing
@testable import SalaryClockAppLib
import SalaryClockCore

/// 그리는 쪽의 enum과 core의 유효 목록은 같은 집합이어야 한다.
///
/// 둘이 어긋나면 조용히 망가진다. core에만 있는 이름은 저장은 되는데 그릴
/// 페이스가 없어 말끔으로 떨어지고, enum에만 있는 이름은 골라 저장하는 순간
/// 유효성 검사에 걸려 설정 전체가 기본값으로 되돌아간다. 어느 쪽도 화면에
/// 오류로 드러나지 않으므로 여기서 묶어 둔다.
@Test("페이스 목록이 core의 유효 목록과 같다")
func clockStyleMatchesCore() {
    #expect(Set(ClockStyle.allCases.map(\.rawValue)) == validClockStyles)
}

@Test("모르는 이름은 말끔으로 떨어진다 — 웹 FACES[style] ?? MinimalFace와 같다")
func unknownStyleFallsBack() {
    #expect(ClockStyle(name: "없는페이스") == .minimal)
    #expect(ClockStyle(name: "") == .minimal)
    #expect(ClockStyle(name: "sundial") == .sundial)
}

@Test("페이스마다 이름표가 있고 서로 겹치지 않는다")
func labelsAreDistinct() {
    let labels = ClockStyle.allCases.map(\.label)
    #expect(labels.allSatisfy { !$0.isEmpty })
    #expect(Set(labels).count == labels.count)
}

/// 기본값은 말끔이다 — 웹 `DEFAULT_SETTINGS.clockStyle`과 같아야 한다.
/// 골든 settings.json이 그 값을 고정하고 있으므로 여기서는 enum 쪽만 본다.
@Test("기본 설정의 페이스를 그릴 수 있다")
func defaultSettingsStyleIsDrawable() {
    #expect(ClockStyle(name: Settings().clockStyle) == .minimal)
}
