import Foundation

/// Localizes strings that originate in collectors or persisted app data.
///
/// Collectors intentionally retain their stable, language-neutral payloads so
/// cached readings and preferences do not change when the interface language
/// changes. This adapter belongs at the presentation boundary instead.
enum UserFacingText {
  private static var isEnglish: Bool {
    UserDefaults.standard.string(forKey: "interfaceLanguage") == InterfaceLanguage.english.rawValue
  }

  static func value(_ text: String) -> String {
    let direct = T(text)
    guard isEnglish, direct == text else { return direct }

    if let suffix = suffix(after: "导出失败：", in: text) {
      return T("导出失败：%@", suffix)
    }
    if let suffix = suffix(after: "自动安装失败：", in: text) {
      return T("自动安装失败：%@", value(suffix))
    }
    if let version = nonEmptySuffix(after: "发现新版本 ", in: text) {
      return T("发现新版本 %@", version)
    }
    if let version = ellipsisArgument(after: "正在下载 IsLandToken ", in: text) {
      return T("正在下载 IsLandToken %@…", version)
    }
    if let percentage = percentArgument(after: "正在下载… ", in: text) {
      return T("正在下载… %@%%", percentage)
    }
    if let failure = previousInstallFailure(in: text) {
      return T("上次自动安装 %@ 失败：%@", failure.version, value(failure.reason))
    }
    return text
  }

  static func quotaTitle(_ title: String) -> String {
    let direct = value(title)
    guard isEnglish, direct == title else { return direct }

    if let parts = quotaWindowParts(in: title) {
      return "\(parts.amount)-\(parts.unit) Quota"
    }
    if let range = title.range(of: " · ", options: .backwards) {
      let prefix = String(title[..<range.lowerBound])
      let suffix = String(title[range.upperBound...])
      if suffix.hasSuffix(" 天") {
        let days = String(suffix.dropLast(2))
        if !prefix.isEmpty, !days.isEmpty, days.allSatisfy(\.isNumber) {
          return "\(prefix) · \(days) days"
        }
      }
    }
    return title
  }

  static func source(_ source: String?) -> String {
    guard let source, !source.isEmpty else { return T("等待连接") }
    let direct = value(source)
    guard direct == source else { return direct }

    let separator = " · "
    guard let range = source.range(of: separator) else { return source }
    let prefix = String(source[..<range.lowerBound])
    let detail = String(source[range.upperBound...])
    return "\(prefix)\(separator)\(localizedSourceDetail(detail))"
  }

  static func refreshDescription(_ description: String) -> String {
    let direct = value(description)
    guard isEnglish, direct == description else { return direct }

    if let minutes = minutesArgument(
      after: "自适应 · 活跃 · ", suffix: " 分钟", in: description)
    {
      return T("自适应 · 活跃 · %@ 分钟", minutes)
    }
    if let minutes = minutesArgument(
      after: "自适应 · 空闲 · ", suffix: " 分钟", in: description)
    {
      return T("自适应 · 空闲 · %@ 分钟", minutes)
    }
    if let minutes = minutesArgument(after: "", suffix: " 分钟", in: description) {
      return T("%@ 分钟", minutes)
    }
    return description
  }

  static func dateTime(_ date: Date) -> String {
    formattedDate(date, dateStyle: .medium, timeStyle: .short)
  }

  static func time(_ date: Date) -> String {
    formattedDate(date, dateStyle: .none, timeStyle: .short)
  }

  private static func localizedSourceDetail(_ detail: String) -> String {
    switch detail.lowercased() {
    case "auto": return isEnglish ? "Automatic" : "自动"
    case "oauth": return "OAuth"
    case "direct": return isEnglish ? "Direct" : "直接读取"
    default: return value(detail)
    }
  }

  private static func formattedDate(
    _ date: Date, dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style
  ) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: isEnglish ? "en_US" : "zh_CN")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = .current
    formatter.dateStyle = dateStyle
    formatter.timeStyle = timeStyle
    return formatter.string(from: date)
  }

  private static func suffix(after prefix: String, in text: String) -> String? {
    guard text.hasPrefix(prefix) else { return nil }
    return String(text.dropFirst(prefix.count))
  }

  private static func nonEmptySuffix(after prefix: String, in text: String) -> String? {
    guard let suffix = suffix(after: prefix, in: text), !suffix.isEmpty else { return nil }
    return suffix
  }

  private static func ellipsisArgument(after prefix: String, in text: String) -> String? {
    guard let suffix = suffix(after: prefix, in: text), suffix.hasSuffix("…") else { return nil }
    let argument = String(suffix.dropLast())
    return argument.isEmpty ? nil : argument
  }

  private static func percentArgument(after prefix: String, in text: String) -> String? {
    guard let suffix = suffix(after: prefix, in: text), suffix.hasSuffix("%") else { return nil }
    let value = String(suffix.dropLast())
    return value.isEmpty ? nil : value
  }

  private static func minutesArgument(after prefix: String, suffix: String, in text: String) -> String? {
    guard text.hasPrefix(prefix), text.hasSuffix(suffix) else { return nil }
    let start = text.index(text.startIndex, offsetBy: prefix.count)
    let end = text.index(text.endIndex, offsetBy: -suffix.count)
    let value = String(text[start..<end])
    return !value.isEmpty && value.allSatisfy(\.isNumber) ? value : nil
  }

  private static func previousInstallFailure(in text: String) -> (version: String, reason: String)? {
    guard text.hasPrefix("上次自动安装 "),
      let failureRange = text.range(of: " 失败：")
    else { return nil }
    let version = String(text.dropFirst("上次自动安装 ".count)[..<failureRange.lowerBound])
    let reason = String(text[failureRange.upperBound...])
    return (version, reason)
  }

  private static func quotaWindowParts(in title: String) -> (amount: String, unit: String)? {
    for (chineseUnit, englishUnit) in [
      ("分钟", "minute"), ("小时", "hour"), ("天", "day"),
    ] {
      let suffix = " \(chineseUnit)额度"
      guard title.hasSuffix(suffix) else { continue }
      let amount = String(title.dropLast(suffix.count))
      if !amount.isEmpty, amount.allSatisfy(\.isNumber) {
        return (amount, englishUnit)
      }
    }
    return nil
  }
}
