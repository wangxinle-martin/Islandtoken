import Foundation

public enum UsageError: LocalizedError {
  case message(String)
  public var errorDescription: String? { if case .message(let value) = self { value } else { nil } }
}

/// Retains quota metadata and the display email; never stores credentials or raw provider responses.
public enum UsageParser {
  public static func date(_ value: Any?) -> Date? {
    if let number = value as? Double, number.isFinite { return Date(timeIntervalSince1970: number) }
    guard let value = value as? String else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
  }
  public static func codexBar(_ data: Data, provider: Provider) throws -> UsageReading {
    let json = try JSONSerialization.jsonObject(with: data)
    let entries = (json as? [[String: Any]]) ?? (json as? [String: Any]).map { [$0] } ?? []
    guard let entry = entries.first(where: { $0["provider"] as? String == provider.rawValue })
    else { throw UsageError.message("CodexBar 未返回此平台的数据，请检查版本与配置。") }
    if entry["error"] != nil, !(entry["error"] is NSNull) {
      throw UsageError.message(safeError((entry["error"] as? [String: Any])?["message"] as? String ?? ""))
    }
    guard let usage = entry["usage"] as? [String: Any] else {
      throw UsageError.message("平台未返回额度数据。")
    }
    var windows: [QuotaWindow] = []
    for key in ["primary", "secondary", "tertiary"] {
      guard let raw = usage[key] as? [String: Any] else { continue }
      windows.append(QuotaWindow(
        id: key, title: title(provider: provider, id: key, minutes: raw["windowMinutes"] as? Int),
        usedPercent: raw["isSyntheticPlaceholder"] as? Bool == true ? nil : raw["usedPercent"] as? Double,
        minutes: raw["windowMinutes"] as? Int, resetsAt: date(raw["resetsAt"]),
        resetDescription: raw["resetDescription"] as? String,
        nextRegenPercent: raw["nextRegenPercent"] as? Double))
    }
    for raw in usage["extraRateWindows"] as? [[String: Any]] ?? [] {
      guard let id = raw["id"] as? String, let value = raw["window"] as? [String: Any] else { continue }
      var window = QuotaWindow(
        id: id, title: raw["title"] as? String ?? id, usedPercent: value["usedPercent"] as? Double,
        minutes: value["windowMinutes"] as? Int, resetsAt: date(value["resetsAt"]),
        resetDescription: value["resetDescription"] as? String,
        nextRegenPercent: value["nextRegenPercent"] as? Double)
      if raw["usageKnown"] as? Bool == false { window.usedPercent = nil }
      if !windows.contains(where: { $0.id == id }) { windows.append(window) }
    }
    let identity = usage["identity"] as? [String: Any]
    var reading = UsageReading(
      provider: provider, windows: windows, updatedAt: date(usage["updatedAt"]) ?? Date(),
      source: "CodexBar · \(entry["source"] as? String ?? "auto")",
      plan: identity?["loginMethod"] as? String)
    reading.accountEmail = identity?["accountEmail"] as? String ?? identity?["email"] as? String
    return reading
  }
  public static func title(provider: Provider, id: String, minutes: Int?) -> String {
    if let minutes, minutes > 0 {
      if minutes >= 1440 { return "\(minutes / 1440) 天额度" }
      if minutes >= 60 { return "\(minutes / 60) 小时额度" }
      return "\(minutes) 分钟额度"
    }
    if provider == .antigravity {
      return id == "primary" ? "Gemini 模型" : id == "secondary" ? "Claude / GPT" : "其他模型"
    }
    return id == "primary" ? "主要额度" : id == "secondary" ? "次要额度" : "其他额度"
  }
  public static func directCodex(_ data: Data) throws -> UsageReading {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      root["rate_limit"] is [String: Any] || root["additional_rate_limits"] is [[String: Any]]
    else { throw UsageError.message("Codex 额度响应格式已变化。") }
    let limit = root["rate_limit"] as? [String: Any] ?? [:]
    var windows = ["primary", "secondary"].compactMap { key -> QuotaWindow? in
      guard let raw = limit[key + "_window"] as? [String: Any] else { return nil }
      let minutes = (raw["limit_window_seconds"] as? Int).map { $0 / 60 }
      return QuotaWindow(
        id: key, title: title(provider: .codex, id: key, minutes: minutes),
        usedPercent: raw["used_percent"] as? Double, minutes: minutes,
        resetsAt: date(raw["reset_at"]))
    }
    for entry in root["additional_rate_limits"] as? [[String: Any]] ?? [] {
      guard let rates = entry["rate_limit"] as? [String: Any] else { continue }
      let name = (entry["limit_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let feature = (entry["metered_feature"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let spark = (name + feature).lowercased().contains("spark")
      let keys = spark ? ["primary_window", "secondary_window"]
        : [rates["primary_window"] is [String: Any] ? "primary_window" : "secondary_window"]
      for key in keys {
        guard let raw = rates[key] as? [String: Any] else { continue }
        let seconds = raw["limit_window_seconds"] as? Int ?? 0
        let minutes: Int? = seconds > 0 ? seconds / 60 : nil
        let weekly = seconds >= 6 * 86400 || (seconds <= 0 && key == "secondary_window")
        let slug = (feature.isEmpty ? name : feature).lowercased()
          .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
        guard spark || !slug.isEmpty else { continue }
        let id = spark ? (weekly ? "codex-spark-weekly" : "codex-spark") : "codex-" + slug
        guard !windows.contains(where: { $0.id == id }) else { continue }
        let reset = raw["reset_at"] as? Double ?? 0
        windows.append(QuotaWindow(id: id,
          title: spark ? (weekly ? "Codex Spark Weekly" : "Codex Spark 5-hour") : (name.isEmpty ? feature : name),
          usedPercent: raw["used_percent"] as? Double, minutes: minutes,
          resetsAt: reset > 0 ? date(reset) : nil))
      }
    }
    return UsageReading(
      provider: .codex, windows: windows, source: "直接读取 · OAuth", plan: root["plan_type"] as? String
    )
  }
  public static func directClaude(_ data: Data) throws -> UsageReading {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw UsageError.message("Claude 额度响应格式已变化。")
    }
    if root["error"] != nil { throw UsageError.message("Claude 暂时限流或登录已过期，请稍后重试。") }
    guard root.keys.contains("five_hour") || root.keys.contains("seven_day") else {
      throw UsageError.message("Claude 额度响应格式已变化。")
    }
    let lanes: [(String, String, Int)] = [
      ("five_hour", "primary", 300), ("seven_day", "secondary", 10080),
      ("seven_day_sonnet", "sonnet", 10080), ("seven_day_opus", "opus", 10080),
    ]
    let windows = lanes.compactMap { key, id, minutes -> QuotaWindow? in
      guard let raw = root[key] as? [String: Any] else { return nil }
      let title =
        id == "sonnet"
        ? "Sonnet · 7 天"
        : id == "opus" ? "Opus · 7 天" : title(provider: .claude, id: id, minutes: minutes)
      return QuotaWindow(
        id: id, title: title, usedPercent: raw["utilization"] as? Double, minutes: minutes,
        resetsAt: date(raw["resets_at"]))
    }
    return UsageReading(provider: .claude, windows: windows, source: "直接读取 · OAuth")
  }
  public static func safeError(_ text: String) -> String {
    let lower = text.lowercased()
    if lower.contains("429") || lower.contains("rate limit") { return "请求受到限流，将在下一刷新周期重试。" }
    if lower.contains("401") || lower.contains("expired") { return "登录已过期，请在原平台重新登录。" }
    if lower.contains("403") || lower.contains("scope") { return "登录权限不足，请重新登录并授权。" }
    if lower.contains("network") || lower.contains("connect") { return "网络连接失败，保留上次成功数据。" }
    return "采集失败，请检查本机登录状态与网络连接。"
  }
}
