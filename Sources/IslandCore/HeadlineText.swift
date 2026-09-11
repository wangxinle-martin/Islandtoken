import Foundation

extension SideConfiguration {
  public func headlineText(reading: UsageReading?, remaining: Bool, revealed: Bool) -> String {
    switch style {
    case .dualPeriod:
      let label = DualPeriodQuota(reading: reading, selectedWindowID: windowID).label(
        remaining: remaining)
      return revealed
        ? label.replacingOccurrences(of: "/", with: "%/")
        : label.replacingOccurrences(of: "%", with: "")
    case .ring, .bar, .segments, .number, .sparkline:
      return reading?.window(windowID)?.percent(remaining: remaining).map {
        String(format: "%.0f", $0)
      } ?? "—"
    }
  }
}
