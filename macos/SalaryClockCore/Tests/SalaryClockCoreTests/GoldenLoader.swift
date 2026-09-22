import Foundation
import Testing

/// shared/golden/*.json 을 저장소 원본에서 직접 읽는다.
///
/// SPM 리소스로 복사하지 않는 이유: 복사본이 생기는 순간 단일 출처가 깨지고,
/// 웹이 골든을 다시 뽑아도 Swift가 옛 값을 보게 된다. #filePath에서
/// 저장소 루트를 거슬러 올라가면 원본을 그대로 읽을 수 있다.
enum Golden {
    /// .../macos/SalaryClockCore/Tests/SalaryClockCoreTests/GoldenLoader.swift → 저장소 루트
    static let root: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // SalaryClockCoreTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // SalaryClockCore
        .deletingLastPathComponent()  // macos
        .deletingLastPathComponent()  // 저장소 루트

    static func url(_ name: String) -> URL {
        root.appendingPathComponent("shared/golden").appendingPathComponent(name)
    }

    static func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let data = try Data(contentsOf: url(name))
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// 골든의 [연, 월(0-based), 일, 시, 분, 초] → epoch ms.
    /// 월이 0-based인 것에 주의 — DateComponents.month는 1-based다.
    static func ms(_ c: [Int]) -> Int {
        var comps = DateComponents()
        comps.year = c[0]
        comps.month = c[1] + 1
        comps.day = c[2]
        comps.hour = c[3]
        comps.minute = c[4]
        comps.second = c[5]
        if c.count > 6 { comps.nanosecond = c[6] * 1_000_000 }
        let date = Calendar.current.date(from: comps)!
        return Int((date.timeIntervalSince1970 * 1000).rounded())
    }

    static func msOrNull(_ c: [Int]?) -> Int? {
        guard let c else { return nil }
        return ms(c)
    }
}

/// 상대 오차 1e-9로 비교한다. 실패하면 어느 값이 어긋났는지 라벨과 함께 남긴다.
func expectClose(
    _ got: Double, _ want: Double, _ label: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let tolerance = max(abs(want), 1.0) * 1e-9
    #expect(
        abs(got - want) <= tolerance,
        "\(label): got \(got), want \(want)",
        sourceLocation: sourceLocation
    )
}
