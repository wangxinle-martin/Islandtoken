import Foundation

public struct DualPeriodQuota {
  public let fiveHour: QuotaWindow?
  public let weekly: QuotaWindow?

  public init(reading: UsageReading?, selectedWindowID: String) {
    guard let reading else {
      fiveHour = nil
      weekly = nil
      return
    }
    if reading.provider == .antigravity {
      let prefix = "antigravity-quota-summary-"
      let group: String?
      if selectedWindowID == "primary" || selectedWindowID.hasPrefix(prefix + "gemini-") {
        group = "gemini"
      } else if selectedWindowID == "secondary" || selectedWindowID.hasPrefix(prefix + "3p-") {
        group = "3p"
      } else {
        group = nil
      }
      fiveHour = group.flatMap { reading.window(prefix + $0 + "-5h") }
      weekly = group.flatMap { reading.window(prefix + $0 + "-weekly") }
    } else {
      // Resolve by actual duration, not slot position. Extra model quotas are not interchangeable.
      let candidates =
        ["primary", "secondary"].contains(selectedWindowID)
        ? reading.windows.filter { ["primary", "secondary"].contains($0.id) }
        : reading.windows.filter { $0.id == selectedWindowID }
      fiveHour = candidates.first { $0.minutes == 300 }
      weekly = candidates.first { $0.minutes == 10080 }
    }
  }

  public func label(remaining: Bool) -> String {
    func number(_ window: QuotaWindow?) -> String {
      window?.percent(remaining: remaining).map { String(format: "%.0f", $0) } ?? "—"
    }
    return "\(number(fiveHour))/\(number(weekly))%"
  }
}
