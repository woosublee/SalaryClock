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
    // 내림은 formatWon이 이미 끝내고 넘기므로, 여기서는 자릿수를 더 깎을 일이
    // 없다. 그래도 .down으로 두면 안 된다 — 넘어오는 값은 내림한 "999.9"가
    // 아니라 그에 가장 가까운 double(999.899999999999977…)이라, 자르는 규칙과
    // 만나면 ₩999.8이 나올 수 있다. 지금 그렇게 안 보이는 건 ICU가 최단
    // 십진 표기로 스냅해 주기 때문일 뿐이다. 이미 내린 값이므로 최근접
    // 반올림은 결과를 바꾸지 않으면서 그 위험만 없앤다.
    f.roundingMode = .halfEven
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
///
/// 웹은 `toFixed(1)`을 쓴다 — double의 실제 값을 십진으로 펼쳐 반올림하되,
/// 정확히 절반이면 큰 쪽(양의 무한대 쪽)을 고른다. `%.1f`도 같은 실제 값을
/// 보지만 절반에서 짝수 쪽으로 가서, 시급 ₩900(초당 0.25)에서 웹 "0.3",
/// 맥 "0.2"로 갈렸다.
///
/// 진짜 절반은 소수부가 정확히 .25나 .75일 때뿐이다(1자리 기준으로 절반이
/// 되는 값 중 2진수로 딱 떨어지는 건 그 둘뿐). 0.15처럼 "보기에 절반"인 값은
/// 실제로는 0.1499…라 `%.1f`가 이미 웹과 같은 답을 낸다 — 그래서 절반인
/// 경우에만 올림(`.up` = 양의 무한대 쪽)으로 바꿔 준다.
public func formatPerSecond(_ n: Double) -> String {
    guard n < 100 else { return String(Int(n.rounded())) }
    let frac = n - n.rounded(.towardZero)
    if frac == 0.25 || frac == 0.75 {
        return String(format: "%.1f", (n * 10).rounded(.up) / 10)
    }
    return String(format: "%.1f", n)
}

public func formatDuration(_ ms: Int) -> String {
    let total = max(0, ms / 1000)
    return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
}

private let WEEKDAYS = ["일", "월", "화", "수", "목", "금", "토"]

/// "2026년 9월 22일 (화)"
public func formatDateKo(_ now: Int) -> String {
    let date = Date(timeIntervalSince1970: Double(now) / 1000)
    let cal = appCalendar
    let dow = cal.component(.weekday, from: date) - 1
    return "\(cal.component(.year, from: date))년 \(cal.component(.month, from: date))월 "
        + "\(cal.component(.day, from: date))일 (\(WEEKDAYS[dow]))"
}

/// "16:53:21" — 24시간제. 오전/오후를 안 쓰면 폭이 고정돼 숫자가 흔들리지 않는다.
public func formatClockTime(_ now: Int) -> String {
    let date = Date(timeIntervalSince1970: Double(now) / 1000)
    let cal = appCalendar
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
