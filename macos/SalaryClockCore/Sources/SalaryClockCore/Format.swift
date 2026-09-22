import Foundation

/// 통화 표기는 ko-KR 고정이다. 기기 로캘을 따르면 ₩가 KRW로 바뀌거나
/// 자릿수 구분이 달라져 웹과 다른 화면이 된다.
private func wonFormatter(_ fractionDigits: Int) -> NumberFormatter {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.locale = Locale(identifier: "ko_KR")
    f.currencyCode = "KRW"
    f.minimumFractionDigits = fractionDigits
    f.maximumFractionDigits = fractionDigits
    // 내림은 아래에서 직접 하므로 포매터는 자르지 않는다
    f.roundingMode = .down
    return f
}

/// 금액 표시. 항상 내린다.
///
/// 반올림하면 아직 벌지 않은 1원이 화면에 먼저 뜬다. 적립 카운터에서는
/// 실제로 쌓인 것보다 많아 보이는 쪽이 덜 쌓인 쪽보다 나쁘다.
public func formatWon(_ n: Double, fractionDigits: Int = 0) -> String {
    let scale = pow(10.0, Double(fractionDigits))
    let floored = (n * scale).rounded(.down) / scale
    return wonFormatter(fractionDigits).string(from: NSNumber(value: floored)) ?? "₩0"
}

/// 초당 적립액. 작은 값에서 0으로 뭉개지지 않도록 소수 1자리를 남긴다.
public func formatPerSecond(_ n: Double) -> String {
    n < 100 ? String(format: "%.1f", n) : String(Int(n.rounded()))
}

public func formatDuration(_ ms: Int) -> String {
    let total = max(0, ms / 1000)
    return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
}

private let WEEKDAYS = ["일", "월", "화", "수", "목", "금", "토"]

/// "2026년 9월 22일 (화)"
public func formatDateKo(_ now: Int) -> String {
    let date = Date(timeIntervalSince1970: Double(now) / 1000)
    let cal = Calendar.current
    let dow = cal.component(.weekday, from: date) - 1
    return "\(cal.component(.year, from: date))년 \(cal.component(.month, from: date))월 "
        + "\(cal.component(.day, from: date))일 (\(WEEKDAYS[dow]))"
}

/// "16:53:21" — 24시간제. 오전/오후를 안 쓰면 폭이 고정돼 숫자가 흔들리지 않는다.
public func formatClockTime(_ now: Int) -> String {
    let date = Date(timeIntervalSince1970: Double(now) / 1000)
    let cal = Calendar.current
    return String(
        format: "%02d:%02d:%02d",
        cal.component(.hour, from: date),
        cal.component(.minute, from: date),
        cal.component(.second, from: date)
    )
}

/// 금액을 억/만 단위로 끊어 읽어준다. 입력창에 0을 몇 개 쳤는지 보기 위한 보조 표시다.
public func formatKoreanUnits(_ n: Double) -> String {
    let v = Int(max(0, n).rounded(.down))
    if v == 0 { return "0원" }

    let grouping = NumberFormatter()
    grouping.numberStyle = .decimal
    grouping.locale = Locale(identifier: "ko_KR")
    let g = { (x: Int) in grouping.string(from: NSNumber(value: x)) ?? String(x) }

    let eok = v / 100_000_000
    let man = (v % 100_000_000) / 10_000
    let rest = v % 10_000

    var parts: [String] = []
    if eok != 0 { parts.append("\(g(eok))억") }
    if man != 0 { parts.append("\(g(man))만") }
    if rest != 0 { parts.append(g(rest)) }

    return parts.joined(separator: " ") + "원"
}
