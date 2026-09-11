import Foundation
import IslandCore

public struct RateWindow {
  public let usedPercent: Double
  public let windowMinutes: Int?
  public let resetsAt: Date?
  public var remainingPercent: Double { max(0, 100 - usedPercent) }
  init?(_ window: QuotaWindow) {
    guard let used = window.usedPercent, used.isFinite else { return nil }
    usedPercent = used
    windowMinutes = window.minutes
    resetsAt = window.resetsAt
  }
}
extension Double {
  func clamped(to range: ClosedRange<Double>) -> Double {
    min(range.upperBound, max(range.lowerBound, self))
  }
}
enum UsageFormatter {
  public static func resetCountdownDescription(from date: Date, now: Date = .init()) -> String {
    let seconds = max(0, date.timeIntervalSince(now))
    if seconds < 1 { return "now" }

    let totalMinutes = max(1, Int(ceil(seconds / 60.0)))
    let days = totalMinutes / (24 * 60)
    let hours = (totalMinutes / 60) % 24
    let minutes = totalMinutes % 60

    if days > 0 {
      if hours > 0 { return "in \(days)d \(hours)h" }
      if minutes > 0 { return "in \(days)d \(minutes)m" }
      return "in \(days)d"
    }
    if hours > 0 {
      if minutes > 0 { return "in \(hours)h \(minutes)m" }
      return "in \(hours)h"
    }
    return "in \(totalMinutes)m"
  }

}
