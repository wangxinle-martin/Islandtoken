import Foundation
import IslandCore
import SwiftUI

@main
struct PopupRegression {
  static func main() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let window = QuotaWindow(
      id: "weekly", title: "Weekly", usedPercent: 75, minutes: 10080,
      resetsAt: now.addingTimeInterval(302400))
    let pace = UsagePace.weekly(window: RateWindow(window)!, now: now)!
    precondition(abs(pace.expectedUsedPercent - 50) < 0.001)
    precondition(pace.deltaPercent == 25 && !pace.willLastToReset)
    precondition(abs(pace.etaSeconds! - 100800) < 0.01)
    var expired = window
    expired.resetsAt = now
    precondition(UsagePace.weekly(window: RateWindow(expired)!, now: now) == nil)
    var unknown = window
    unknown.usedPercent = nil
    precondition(RateWindow(unknown) == nil)
    var future = window
    future.resetsAt = now.addingTimeInterval(700000)
    precondition(UsagePace.weekly(window: RateWindow(future)!, now: now) == nil)
    print("PASS upstream pace and invalid-window boundaries")
    for expanded in [false, true] {
      let rect = CGRect(x: 0, y: 0, width: 980, height: expanded ? 540 : 30)
      var closed = false
      var topLine = false
      IslandLowerEdge(expanded: expanded).path(in: rect).cgPath.applyWithBlock { element in
        if element.pointee.type == .closeSubpath { closed = true }
        if element.pointee.type == .addLineToPoint && element.pointee.points[0].y == 0 {
          topLine = true
        }
      }
      precondition(!closed && !topLine, "Refresh outline must never cross the top edge")
    }
    print("PASS open refresh outline for compact and expanded island")
  }
}
