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
    if let version = ellipsisArgument(after: "正在下载并验证 IsLandToken ", in: text) {
      return T("正在下载并验证 IsLandToken %@…", version)
    }
    if let percentage = percentArgument(after: "正在下载… ", in: text) {
      return T("正在下载… %@%%", percentage)
    }
    if let detail = nonEmptySuffix(after: "更新辅助程序未能启动：", in: text) {
      return T("更新辅助程序未能启动：%@", value(detail))
    }
    if let detail = nonEmptySuffix(after: "自动下载失败；请检查网络以及 gh auth status。", in: text) {
      return T("自动下载失败；请检查网络以及 gh auth status。%@", value(detail))
    }
    if let detail = sentenceArgument(after: "无法设置更新辅助程序权限：", in: text) {
      return T("无法设置更新辅助程序权限：%@。", detail)
    }
    if let detail = sentenceArgument(after: "无法原子替换应用：", in: text) {
      return T("无法原子替换应用：%@。", detail)
    }
    if let failure = rollbackFailure(in: text) {
      return T(
        "新版启动失败，且自动回滚失败。旧版仍保留在 %@。 %@",
        failure.path, value(failure.reason))
    }
    if let failure = relaunchFailure(in: text) {
      return T(
        "新版启动失败，旧版已恢复，但自动重启失败。请手动打开 %@。 %@",
        failure.path, value(failure.reason))
    }
    if let executable = timeoutExecutable(in: text) {
      return T("执行 %@ 超时。", executable)
    }
    if let failure = processFailure(in: text) {
      if let detail = failure.detail {
        return T("%@ 执行失败：%@", failure.executable, value(detail))
      }
      return T("%@ 执行失败。", failure.executable)
    }
    if let failure = previousInstallFailure(in: text) {
      return T("上次自动安装 %@ 失败：%@", failure.version, value(failure.reason))
    }
    return text
  }

  /// GitHub release bodies include both language sections, while the app shows
  /// only the section selected in Settings. Older one-language release bodies
  /// remain readable as-is.
  static func releaseNotes(_ text: String) -> String {
    guard let chinese = markdownSection("中文", in: text),
      let english = markdownSection("English", in: text)
    else { return text }
    return isEnglish ? english : chinese
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

  private static func sentenceArgument(after prefix: String, in text: String) -> String? {
    guard let suffix = suffix(after: prefix, in: text), suffix.hasSuffix("。") else { return nil }
    let argument = String(suffix.dropLast())
    return argument.isEmpty ? nil : argument
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

  private static func rollbackFailure(in text: String) -> (path: String, reason: String)? {
    twoPartValue(
      after: "新版启动失败，且自动回滚失败。旧版仍保留在 ",
      separator: "。 ", in: text)
  }

  private static func relaunchFailure(in text: String) -> (path: String, reason: String)? {
    twoPartValue(
      after: "新版启动失败，旧版已恢复，但自动重启失败。请手动打开 ",
      separator: "。 ", in: text)
  }

  private static func twoPartValue(
    after prefix: String, separator: String, in text: String
  ) -> (path: String, reason: String)? {
    guard let tail = nonEmptySuffix(after: prefix, in: text),
      let separatorRange = tail.range(of: separator)
    else { return nil }
    let path = String(tail[..<separatorRange.lowerBound])
    let reason = String(tail[separatorRange.upperBound...])
    guard !path.isEmpty, !reason.isEmpty else { return nil }
    return (path, reason)
  }

  private static func timeoutExecutable(in text: String) -> String? {
    let prefix = "执行 "
    let suffix = " 超时。"
    guard text.hasPrefix(prefix), text.hasSuffix(suffix) else { return nil }
    let executable = String(text.dropFirst(prefix.count).dropLast(suffix.count))
    return executable.isEmpty ? nil : executable
  }

  private static func processFailure(in text: String) -> (executable: String, detail: String?)? {
    let separator = " 执行失败"
    guard let separatorRange = text.range(of: separator) else { return nil }
    let executable = String(text[..<separatorRange.lowerBound])
    let remainder = String(text[separatorRange.upperBound...])
    guard !executable.isEmpty else { return nil }
    if remainder == "。" { return (executable, nil) }
    guard remainder.hasPrefix("：") else { return nil }
    let detail = String(remainder.dropFirst())
    return detail.isEmpty ? nil : (executable, detail)
  }

  private static func markdownSection(_ title: String, in text: String) -> String? {
    let heading = "### \(title)"
    guard let headingRange = text.range(of: heading) else { return nil }
    let remainder = text[headingRange.upperBound...]
    let sectionEnd = remainder.range(of: "\n### ")?.lowerBound ?? remainder.endIndex
    let section = String(remainder[..<sectionEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
    return section.isEmpty ? nil : section
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
