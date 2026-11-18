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
    var example = window
    example.resetsAt = now.addingTimeInterval(604800 * 0.88)
    for (used, inDeficit) in [(20.0, true), (13.0, false), (8.0, false)] {
      example.usedPercent = used
      let examplePace = UsagePace.weekly(window: RateWindow(example)!, now: now)!
      precondition(abs(examplePace.expectedUsedPercent - 12) < 0.001)
      precondition(examplePace.isInDeficit == inDeficit)
    }
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
    let compactRect = CGRect(x: 0, y: 0, width: 356, height: 38)
    let ordinaryShape = IslandShape(expanded: false)
    let trailingAttached = IslandShape(expanded: false, notchAttachment: .trailing)
    let leadingAttached = IslandShape(expanded: false, notchAttachment: .leading)
    precondition(
      !ordinaryShape.path(in: compactRect).contains(CGPoint(x: compactRect.maxX - 3, y: 6)),
      "A free trailing corner must retain its shoulder")
    precondition(
      trailingAttached.path(in: compactRect).contains(CGPoint(x: compactRect.maxX - 3, y: 6)),
      "A left-side Island must remain flush with the trailing notch edge")
    precondition(
      !ordinaryShape.path(in: compactRect).contains(CGPoint(x: compactRect.minX + 3, y: 6)),
      "A free leading corner must retain its shoulder")
    precondition(
      leadingAttached.path(in: compactRect).contains(CGPoint(x: compactRect.minX + 3, y: 6)),
      "A right-side Island must remain flush with the leading notch edge")
    print("PASS notch attachment edges remain flush")
    precondition(
      UsageMenuCardLayout.popupBottomSafetyPadding + 10 >= 24,
      "Popup actions must stay above the expanded island's bottom corners")
    precondition(
      UsageMenuCardLayout.actionAreaReservedHeight
        == UsageMenuCardLayout.actionAreaContentHeight + UsageMenuCardLayout.popupBottomSafetyPadding,
      "Popup actions need a fixed, centered content region plus a separate corner-safe inset")
    precondition(
      UsageMenuCardLayout.actionAreaContentHeight >= 36,
      "Popup action controls need a compact but usable 36pt minimum lane")
    print("PASS popup action bottom-corner safety inset")
    for count in 1...6 {
      let cards = UsageMenuCardLayout.columnWidth * CGFloat(count)
      let width = UsageMenuCardLayout.expandedPopupWidth(
        providerCount: count, compactWidth: 320, screenWidth: 1512, baseline: 580)
      precondition(
        width >= min(cards, 1512 - 48),
        "Every island provider column must stay visible up to the screen cap")
      precondition(width >= 580 && width >= 320)
    }
    precondition(
      UsageMenuCardLayout.expandedPopupWidth(
        providerCount: 1, compactWidth: 320, screenWidth: 1512, baseline: 580) == 580)
    precondition(
      UsageMenuCardLayout.expandedPopupWidth(
        providerCount: 2, compactWidth: 320, screenWidth: 1512, baseline: 580) == 580)
    precondition(
      UsageMenuCardLayout.expandedPopupWidth(
        providerCount: 3, compactWidth: 320, screenWidth: 1512, baseline: 580) == 870)
    precondition(
      UsageMenuCardLayout.expandedPopupWidth(
        providerCount: 5, compactWidth: 320, screenWidth: 1512, baseline: 580) == 1450)
    precondition(
      UsageMenuCardLayout.expandedPopupWidth(
        providerCount: 6, compactWidth: 320, screenWidth: 1512, baseline: 580) == 1464)
    precondition(
      UsageMenuCardLayout.expandedPopupWidth(
        providerCount: 5, compactWidth: 320, screenWidth: 800, baseline: 580) == 752)
    print("PASS expanded popup width grows with island provider count")
  }
}
