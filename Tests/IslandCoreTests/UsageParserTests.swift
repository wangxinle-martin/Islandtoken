import Foundation

#if canImport(XCTest)
  import XCTest
  @testable import IslandCore
#else
  // Command Line Tools omit XCTest. The same test bodies run through script/test.sh.
  class XCTestCase {}
  func XCTAssertEqual<T: Equatable>(
    _ lhs: T, _ rhs: T, file: StaticString = #file, line: UInt = #line
  ) {
    precondition(lhs == rhs, "Expected \(rhs), got \(lhs)", file: file, line: line)
  }
  func XCTAssertTrue(_ value: Bool, file: StaticString = #file, line: UInt = #line) {
    precondition(value, "Expected true", file: file, line: line)
  }
  func XCTAssertFalse(_ value: Bool, file: StaticString = #file, line: UInt = #line) {
    precondition(!value, "Expected false", file: file, line: line)
  }
  func XCTAssertNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) {
    precondition(value == nil, "Expected nil", file: file, line: line)
  }
  func XCTAssertNotNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) {
    precondition(value != nil, "Expected a value", file: file, line: line)
  }
  func XCTAssertThrowsError<T>(
    _ expression: @autoclosure () throws -> T, _ inspect: (Error) -> Void = { _ in },
    file: StaticString = #file, line: UInt = #line
  ) {
    do {
      _ = try expression()
      preconditionFailure("Expected an error", file: file, line: line)
    } catch { inspect(error) }
  }
  @main
  struct PortableTestRunner {
    static func main() throws {
      let suite = UsageParserTests()
      let checks: [(String, () throws -> Void)] = [
        ("fractional percentage", suite.testCodexBarRemainingAndFractionalPercentage),
        ("unknown and synthetic", suite.testSyntheticAndUnknownAreNotFullOrExhaustedQuota),
        ("weekly primary", suite.testSingleWeeklyPrimaryKeepsActualDuration),
        ("Claude null window", suite.testDirectClaudeNullAndFractionalWindow),
        ("malformed and error redaction", suite.testMalformedAndProviderFailureDoNotBecomeZero),
        ("missing percent", suite.testMissingUsedPercentIsUnknown),
        ("clamped display", suite.testOutOfRangeClampsOnlyForDisplay),
        ("preference persistence", suite.testPreferencesRoundTripAndClamping),
        ("notch geometry", suite.testNotchAndAutohideHeight),
        ("stale and precise selection", suite.testStaleReadingAndPreciseSelection),
        ("unknown costs", suite.testCostKeepsMissingValuesMissing),
        ("dual period mapping", suite.testDualPeriodMapping),
        ("detail entry invariant", suite.testDetailEntryInvariant),
        ("legacy preferences migration", suite.testLegacyPreferencesMigration),
        ("island side visibility", suite.testIslandSideVisibility),
        ("headline style switching", suite.testHeadlineStyleSwitching),
        ("requested default preferences", suite.testRequestedDefaultPreferences),
        ("reset credit metadata", suite.testResetCreditMetadata),
        ("release versions", suite.testReleaseVersions),
        ("upstream Codex additional limits", suite.testAdditionalCodexLimits),
        ("upstream rolling regeneration", suite.testRollingRegeneration),
      ]
      for (name, check) in checks {
        try check()
        print("PASS \(name)")
      }
      print("\(checks.count) tests passed.")
    }
  }
#endif

final class UsageParserTests: XCTestCase {
  func testReleaseVersions() {
    XCTAssertTrue(AppVersion.isNewer("0.10.0", than: "0.9.9"))
    XCTAssertFalse(AppVersion.isNewer("0.2.0", than: "0.2.0"))
    XCTAssertFalse(AppVersion.isNewer("0.1.9", than: "0.2.0"))
    XCTAssertFalse(AppVersion.isNewer("0.3.0-beta", than: "0.2.0"))
    XCTAssertNil(AppVersion.components("broken"))
    XCTAssertNil(AppVersion.components("+1.2.3"))
    XCTAssertNil(AppVersion.components("1..3"))
  }

  func testAdditionalCodexLimits() throws {
    let data = Data(#"{"rate_limit":{"primary_window":{"used_percent":12,"limit_window_seconds":18000}},"additional_rate_limits":[{"limit_name":"Codex Spark","rate_limit":{"primary_window":{"used_percent":35,"limit_window_seconds":18000,"reset_at":0},"secondary_window":{"used_percent":61,"limit_window_seconds":604800}}},{"limit_name":"Reserve","metered_feature":"gpt-reserve","rate_limit":{"secondary_window":{"used_percent":9,"limit_window_seconds":604800}}}]}"#.utf8)
    let reading = try UsageParser.directCodex(data)
    XCTAssertEqual(reading.windows.count, 4)
    XCTAssertEqual(reading.window("codex-spark")?.usedPercent, 35)
    XCTAssertNil(reading.window("codex-spark")?.resetsAt)
    XCTAssertEqual(reading.window("codex-spark-weekly")?.minutes, 10080)
    XCTAssertEqual(reading.window("codex-gpt-reserve")?.title, "Reserve")
  }
  func testRollingRegeneration() throws {
    let data = Data(#"[{"provider":"codex","usage":{"primary":{"usedPercent":40,"nextRegenPercent":12.5},"extraRateWindows":[{"id":"pending","title":"Pending","usageKnown":false,"window":{"usedPercent":100}}]}}]"#.utf8)
    let reading = try UsageParser.codexBar(data, provider: .codex)
    XCTAssertEqual(reading.window("primary")?.nextRegenPercent, 12.5)
    XCTAssertNil(reading.window("pending")?.usedPercent)
    let cached = try JSONDecoder().decode(UsageReading.self, from: JSONEncoder().encode(reading))
    XCTAssertEqual(cached.window("primary")?.nextRegenPercent, 12.5)
  }

  func testHeadlineStyleSwitching() {
    let reading = UsageReading(
      provider: .codex,
      windows: [
        QuotaWindow(id: "primary", title: "5h", usedPercent: 77, minutes: 300),
        QuotaWindow(id: "secondary", title: "week", usedPercent: 72, minutes: 10080),
      ], source: "test")
    var side = SideConfiguration(provider: .codex, style: .number)
    for style in ChartStyle.allCases {
      side.style = style
      side.windowIDs = ["primary", "secondary"]
      XCTAssertEqual(side.headlineText(reading: reading, remaining: true, revealed: false), "23|28")
      XCTAssertEqual(side.headlineText(reading: reading, remaining: true, revealed: true), "23%|28%")
      side.windowIDs = ["secondary", "missing", "primary", "secondary"]
      XCTAssertEqual(side.windowIDs, ["secondary", "missing", "primary"])
      XCTAssertEqual(side.headlineText(reading: reading, remaining: false, revealed: false), "72|—|77")
      side.windowID = "secondary"
      XCTAssertEqual(side.headlineText(reading: reading, remaining: true, revealed: false), "28")
    }
    side.windowIDs = []
    XCTAssertEqual(side.windowIDs, ["primary"])
  }

  func testIslandSideVisibility() throws {
    var prefs = Preferences()
    XCTAssertEqual(prefs.islandSideVisibility, .both)
    prefs.islandSideVisibility = .left
    let left = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(prefs))
    XCTAssertEqual(left.islandSideVisibility, .left)
    prefs.islandSideVisibility = .right
    let right = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(prefs))
    XCTAssertEqual(right.islandSideVisibility, .right)
  }
  func testRequestedDefaultPreferences() {
    let preferences = Preferences()
    XCTAssertEqual(preferences.left.provider, .claude)
    XCTAssertEqual(preferences.left.style, .ring)
    XCTAssertEqual(preferences.left.windowIDs, ["primary", "secondary"])
    XCTAssertEqual(preferences.right.provider, .codex)
    XCTAssertEqual(preferences.right.style, .number)
    XCTAssertEqual(preferences.right.windowIDs, ["primary", "secondary"])
    XCTAssertEqual(preferences.enabled, [.claude, .codex])
    XCTAssertEqual(preferences.islandSideVisibility, .both)
    XCTAssertTrue(preferences.hoverExpand)
    XCTAssertFalse(preferences.clickExpand)
    XCTAssertTrue(preferences.remaining)
    XCTAssertTrue(preferences.absoluteResetTime)
    XCTAssertEqual(preferences.refreshAnimation, .random)
    XCTAssertTrue(preferences.openDashboardOnLaunch)
    XCTAssertTrue(preferences.showMenuBarIcon)
  }
  func testDetailEntryInvariant() {
    for mask in 0..<8 {
      var prefs = Preferences()
      prefs.clickExpand = mask & 1 != 0
      prefs.hoverExpand = mask & 2 != 0
      prefs.showMenuBarIcon = mask & 4 != 0
      prefs.normalize()
      XCTAssertFalse(prefs.clickExpand && prefs.hoverExpand)
      if mask != 0 {
        XCTAssertEqual(prefs.clickExpand, mask & 1 != 0 && mask & 2 == 0)
        XCTAssertEqual(prefs.hoverExpand, mask & 2 != 0)
        XCTAssertEqual(prefs.showMenuBarIcon, mask & 4 != 0)
      }
      prefs.showIsland = false
      prefs.normalize()
      XCTAssertTrue(prefs.showMenuBarIcon)
    }
  }
  func testLegacyPreferencesMigration() throws {
    var prefs = Preferences()
    prefs.right.provider = .antigravity
    prefs.left.style = .number
    prefs.left.windowIDs = ["primary", "secondary"]
    prefs.hoverExpand = true
    var old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(prefs)) as! [String: Any]
    old.removeValue(forKey: "clickExpand")
    old.removeValue(forKey: "showMenuBarIcon")
    let restored = try JSONDecoder().decode(
      Preferences.self, from: JSONSerialization.data(withJSONObject: old))
    XCTAssertEqual(restored.right.provider, .antigravity)
    XCTAssertEqual(restored.left.style, .number)
    XCTAssertEqual(restored.left.windowIDs, ["primary", "secondary"])
    for (provider, id, expected) in [
      ("codex", "primary", ["primary", "secondary"]),
      ("antigravity", "secondary", ["antigravity-quota-summary-3p-5h", "antigravity-quota-summary-3p-weekly"])
    ] {
      let legacy = "{\"provider\":\"\(provider)\",\"windowID\":\"\(id)\",\"style\":\"dualPeriod\"}"
      let migrated = try JSONDecoder().decode(SideConfiguration.self, from: Data(legacy.utf8))
      XCTAssertEqual(migrated.style, .number)
      XCTAssertEqual(migrated.windowIDs, expected)
      let roundTrip = try JSONDecoder().decode(SideConfiguration.self, from: JSONEncoder().encode(migrated))
      XCTAssertEqual(roundTrip, migrated)
    }
    let single = try JSONDecoder().decode(SideConfiguration.self,
      from: Data(#"{"provider":"codex","windowID":"model-x","style":"ring"}"#.utf8))
    XCTAssertEqual(single.windowIDs, ["model-x"])
    XCTAssertEqual(single.style, .ring)
    XCTAssertTrue(restored.hoverExpand)
    XCTAssertFalse(restored.clickExpand)
    XCTAssertTrue(restored.showMenuBarIcon)
  }
  func testDualPeriodMapping() {
    let reading = UsageReading(
      provider: .codex,
      windows: [
        QuotaWindow(id: "primary", title: "week", usedPercent: 24, minutes: 10080),
        QuotaWindow(id: "secondary", title: "session", usedPercent: 75, minutes: 300),
      ], source: "test")
    let pair = DualPeriodQuota(reading: reading, selectedWindowID: "primary")
    XCTAssertEqual(pair.label(remaining: true), "25/76%")
    XCTAssertEqual(pair.label(remaining: false), "75/24%")
    var weeklyOnly = reading
    weeklyOnly.windows.removeLast()
    XCTAssertEqual(
      DualPeriodQuota(reading: weeklyOnly, selectedWindowID: "primary").label(remaining: true),
      "—/76%")
    let anti = UsageReading(
      provider: .antigravity,
      windows: [
        QuotaWindow(id: "antigravity-quota-summary-gemini-5h", title: "Gemini", usedPercent: 75),
        QuotaWindow(
          id: "antigravity-quota-summary-gemini-weekly", title: "Gemini", usedPercent: 24),
        QuotaWindow(id: "antigravity-quota-summary-3p-weekly", title: "Claude", usedPercent: 90),
      ], source: "test")
    XCTAssertEqual(
      DualPeriodQuota(reading: anti, selectedWindowID: "primary").label(remaining: true), "25/76%")
    XCTAssertEqual(
      DualPeriodQuota(reading: anti, selectedWindowID: "secondary").label(remaining: true), "—/10%")
  }
  private func data(_ value: String) -> Data { Data(value.utf8) }
  func testCodexBarRemainingAndFractionalPercentage() throws {
    let reading = try UsageParser.codexBar(
      data(
        """
        [{"provider":"claude","source":"oauth","usage":{"primary":{"usedPercent":0.5,"windowMinutes":300,"resetsAt":"2026-09-07T10:00:00.123Z"},"updatedAt":"2026-09-07T08:00:00Z"}}]
        """), provider: .claude)
    XCTAssertEqual(reading.windows[0].remainingPercent, 99.5)
    XCTAssertNotNil(reading.windows[0].resetsAt)
    XCTAssertEqual(reading.windows[0].title, "5 小时额度")
  }
  func testSyntheticAndUnknownAreNotFullOrExhaustedQuota() throws {
    let reading = try UsageParser.codexBar(
      data(
        """
        [{"provider":"antigravity","source":"cli","usage":{"primary":{"usedPercent":0,"isSyntheticPlaceholder":true},"extraRateWindows":[{"id":"model-a","title":"Gemini Pro","usageKnown":false,"window":{"usedPercent":100}}]}}]
        """), provider: .antigravity)
    XCTAssertNil(reading.windows[0].remainingPercent)
    XCTAssertNil(reading.windows[1].remainingPercent)
    XCTAssertNil(reading.window("secondary"))
  }
  func testSingleWeeklyPrimaryKeepsActualDuration() throws {
    let reading = try UsageParser.directCodex(
      data(
        """
        {"plan_type":"pro","rate_limit":{"primary_window":{"used_percent":72,"limit_window_seconds":604800,"reset_at":1790000000},"secondary_window":null}}
        """))
    XCTAssertEqual(reading.windows.count, 1)
    XCTAssertEqual(reading.windows[0].title, "7 天额度")
    XCTAssertEqual(reading.windows[0].remainingPercent, 28)
    XCTAssertNil(reading.window("secondary"))
  }
  func testDirectClaudeNullAndFractionalWindow() throws {
    let reading = try UsageParser.directClaude(
      data(
        """
        {"five_hour":{"utilization":0.5,"resets_at":"2026-09-07T10:00:00Z"},"seven_day":null}
        """))
    XCTAssertEqual(reading.windows.count, 1)
    XCTAssertEqual(reading.windows[0].remainingPercent, 99.5)
  }
  func testMalformedAndProviderFailureDoNotBecomeZero() {
    XCTAssertThrowsError(try UsageParser.directCodex(data("{}")))
    XCTAssertThrowsError(try UsageParser.directClaude(data("{}")))
    XCTAssertThrowsError(
      try UsageParser.codexBar(
        data("[{\"provider\":\"codex\",\"error\":{\"message\":\"HTTP 401 secret-token\"}}]"),
        provider: .codex)
    ) { error in
      XCTAssertFalse(error.localizedDescription.contains("secret-token"))
    }
    XCTAssertThrowsError(try UsageParser.codexBar(data("[]"), provider: .codex))
  }
  func testMissingUsedPercentIsUnknown() throws {
    let reading = try UsageParser.codexBar(
      data("[{\"provider\":\"codex\",\"usage\":{\"primary\":{\"windowMinutes\":300}}}]"),
      provider: .codex)
    XCTAssertNil(reading.windows[0].remainingPercent)
  }
  func testOutOfRangeClampsOnlyForDisplay() {
    let exhausted = QuotaWindow(id: "primary", title: "test", usedPercent: 150)
    XCTAssertEqual(exhausted.usedPercent, 150)
    XCTAssertEqual(exhausted.remainingPercent, 0)
    XCTAssertEqual(exhausted.percent(remaining: false), 100)
    XCTAssertNil(QuotaWindow(id: "a", title: "test", usedPercent: .nan).remainingPercent)
  }
  func testPreferencesRoundTripAndClamping() throws {
    var preferences = Preferences()
    preferences.left = SideConfiguration(provider: .antigravity, style: .segments)
    preferences.right.windowID = "model-claude"
    preferences.refreshMinutes = 1
    preferences.sideWidth = 300
    preferences.criticalPercent = 99
    preferences.normalize()
    XCTAssertEqual(preferences.refreshMinutes, 1)
    XCTAssertEqual(preferences.sideWidth, 180)
    XCTAssertEqual(preferences.criticalPercent, 20)
    let restored = try JSONDecoder().decode(
      Preferences.self, from: JSONEncoder().encode(preferences))
    XCTAssertEqual(restored, preferences)
    XCTAssertTrue(restored.providersToFetch.contains(.antigravity))
  }
  func testNotchAndAutohideHeight() {
    XCTAssertEqual(IslandGeometry.menuHeight(safeTop: 38, visibleDelta: 39, statusBar: 24), 38)
    XCTAssertEqual(IslandGeometry.menuHeight(safeTop: 38, visibleDelta: 25, statusBar: 24), 24)
    XCTAssertEqual(IslandGeometry.menuHeight(safeTop: 38, visibleDelta: 0, statusBar: 24), 38)
    XCTAssertEqual(IslandGeometry.menuHeight(safeTop: 0, visibleDelta: 0, statusBar: 24), 24)
  }
  func testStaleReadingAndPreciseSelection() {
    let reading = UsageReading(
      provider: .codex, windows: [QuotaWindow(id: "primary", title: "weekly", usedPercent: 5)],
      updatedAt: Date(timeIntervalSince1970: 1), source: "test")
    XCTAssertTrue(reading.stale(refreshMinutes: 5))
    XCTAssertNil(reading.window("secondary"))
  }
  func testCostKeepsMissingValuesMissing() throws {
    let reading = try JSONDecoder().decode(
      CostReading.self,
      from: data(
        "{\"provider\":\"codex\",\"sessionTokens\":12345,\"daily\":[{\"date\":\"2026-09-07\",\"totalTokens\":12345}]}"
      ))
    XCTAssertEqual(reading.sessionTokens, 12345)
    XCTAssertNil(reading.sessionCostUSD)
    XCTAssertNil(reading.daily?.first?.totalCost)
  }
  func testResetCreditMetadata() throws {
    let payload =
      #"{"provider":"codex","usage":{"primary":{"usedPercent":20},"codexResetCredits":{"credits":[{"id":"not-retained","status":"available","expires_at":"2026-10-04T01:01:00Z"},{"status":"redeemed","expires_at":"2026-10-05T01:01:00Z"}]}}}"#
    let reading = try UsageParser.codexBar(Data(payload.utf8), provider: .codex)
    XCTAssertEqual(reading.resetCredits?.count, 1)
    XCTAssertNotNil(reading.resetCredits?.first?.expiresAt)
    let encoded = try JSONEncoder().encode(reading)
    XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("not-retained"))
    let restored = try JSONDecoder().decode(UsageReading.self, from: encoded)
    XCTAssertEqual(restored.resetCredits?.first?.expiresAt, reading.resetCredits?.first?.expiresAt)
    let legacy = try UsageParser.codexBar(
      Data(#"{"provider":"codex","usage":{"primary":{"usedPercent":20}}}"#.utf8), provider: .codex)
    XCTAssertNil(legacy.resetCredits)
  }

}
