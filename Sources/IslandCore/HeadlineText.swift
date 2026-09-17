import Foundation

extension SideConfiguration {
  public func headlineText(reading: UsageReading?, remaining: Bool, revealed: Bool) -> String {
    displayWindowIDs(reading: reading).map { id in
      let number =
        reading?.window(id)?.percent(remaining: remaining).map {
          String(format: "%.0f", $0)
        } ?? "—"
      return number + (revealed ? "%" : "")
    }.joined(separator: "|")
  }
}
