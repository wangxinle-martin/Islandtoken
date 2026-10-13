import Combine
import Foundation
import IslandCore

private final class MemoryDefaults: UserDefaults {
  var values: [String: Data] = [:]
  var writes = 0
  override func data(forKey key: String) -> Data? { values[key] }
  override func set(_ value: Any?, forKey key: String) {
    writes += 1
    values[key] = value as? Data
  }
}

@main
struct StoreRegression {
  @MainActor static func main() async {
    let defaults = MemoryDefaults()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let store = AppStore(defaults: defaults, directory: directory)
    var changes = 0
    let observer = store.objectWillChange.sink { changes += 1 }
    // Reproduce SwiftUI's repeated insertion writeback, including key-path mutation.
    for _ in 0..<1000 { store.preferences.showMenuBarIcon = true }
    precondition(
      changes == 0 && defaults.writes == 0, "Unchanged bindings must not publish or persist")
    store.preferences.showMenuBarIcon = false
    precondition(changes == 1 && defaults.writes == 1, "A real change must publish once")
    for _ in 0..<1000 { store.preferences.showMenuBarIcon = false }
    precondition(changes == 1 && defaults.writes == 1)
    store.preferences.showMenuBarIcon = true
    store.preferences.clickExpand = false
    let before = changes
    for _ in 0..<1000 { store.preferences.showMenuBarIcon = false }
    precondition(
      !store.preferences.showMenuBarIcon && changes == before + 1,
      "Menu bar is independent; repeated writes must be ignored")
    for mode in DetailInteraction.allCases {
      store.preferences.detailInteraction = mode
      precondition(store.preferences.detailInteraction == mode)
      let decoded = try! JSONDecoder().decode(
        Preferences.self, from: JSONEncoder().encode(store.preferences))
      precondition(decoded.detailInteraction == mode)
    }
    let restored = AppStore(defaults: defaults, directory: directory)
    precondition(
      restored.preferences == store.preferences, "Persistence must preserve accepted settings")
    store.readings[.codex] = UsageReading(
      provider: .codex,
      windows: [QuotaWindow(id: "primary", title: "Live", usedPercent: 42, minutes: 300)],
      source: "live")
    for _ in 0..<10 {
      store.refreshing = true
      store.refreshingCost = true
      store.setDemo(true)
      precondition(store.demoMode && !store.refreshing && !store.refreshingCost)
      precondition(store.readings[.codex]?.source == "演示数据")
      for preset in DemoPreset.allCases {
        let changesBeforePreset = changes
        store.setDemoPreset(preset)
        precondition(
          changes - changesBeforePreset <= 3,
          "Demo regeneration must publish one complete snapshot, not every generated sample")
        let codexRemaining = store.readings[.codex]?.windows.first?.remainingPercent
        let antigravityRemaining = store.readings[.antigravity]?.windows.last?.remainingPercent
        if preset.usesRandomData {
          precondition((3...97).contains(Int(codexRemaining ?? -1)))
          precondition((3...97).contains(Int(antigravityRemaining ?? -1)))
          let antigravityValues = store.readings[.antigravity]?.windows.compactMap(\.remainingPercent) ?? []
          precondition(
            Set(antigravityValues).count == antigravityValues.count,
            "Each demo quota must receive an independent random value")
          for provider in Provider.allCases {
            for window in store.readings[provider]?.windows ?? [] {
              let history = store.history(provider: provider, windowID: window.id)
              precondition(
                history.count == 36,
                "Each demo quota must receive a complete independent trend")
              precondition(
                history.last?.used == window.usedPercent,
                "The final demo trend value must match its quota")
            }
          }
        } else {
          precondition(codexRemaining == preset.remaining)
          precondition(antigravityRemaining == preset.remaining)
        }
      }
      store.setDemo(false)
      precondition(!store.demoMode && store.readings[.codex]?.source == "live")
      precondition(store.readings[.codex]?.windows.first?.usedPercent == 42)
    }
    store.preferences.refreshMinutes = 0
    precondition(store.effectiveRefreshMinutes == 5)
    let adaptiveReload = AppStore(defaults: defaults, directory: directory)
    precondition(adaptiveReload.preferences.refreshMinutes == 0)
    store.preferences.refreshMinutes = 1
    precondition(store.effectiveRefreshMinutes == 1)
    print("PASS adaptive preference persistence and one-minute interval")
    store.setDemo(true)  // Cancel the pending live schedule before exiting.
    print("PASS repeated demo/live switching while usage and cost refresh are busy")
    let historyStart = Date(timeIntervalSince1970: 1_700_000_000)
    store.samples = (0..<400).flatMap { offset in
      [
        Sample(
          provider: .codex, windowID: "history-target",
          date: historyStart.addingTimeInterval(Double(offset)), used: Double(offset)),
        Sample(
          provider: .claude, windowID: "unrelated",
          date: historyStart.addingTimeInterval(Double(offset)), used: Double(offset)),
      ]
    }
    let expectedHistory = Array(
      store.samples.filter { $0.provider == .codex && $0.windowID == "history-target" }.suffix(144)
    ).map(\.id)
    precondition(
      store.history(provider: .codex, windowID: "history-target").map(\.id) == expectedHistory,
      "History must retain the newest matching samples in chronological order")
    print("PASS bounded history query preserves recent chronological samples")
    let monitor = AgentActivityMonitor()
    let now = Date()
    let first = await monitor.observe(
      output: "42 0:00.10 /usr/local/bin/codex", providers: [.codex], now: now)
    precondition(first)
    let idle = await monitor.observe(
      output: "42 0:00.10 /usr/local/bin/codex", providers: [.codex],
      now: now.addingTimeInterval(121))
    precondition(!idle)
    let active = await monitor.observe(
      output: "42 0:00.50 /usr/local/bin/codex", providers: [.codex],
      now: now.addingTimeInterval(136))
    precondition(active)
    let unrelated = await AgentActivityMonitor().observe(
      output: "43 5:20.00 /Applications/CodexBar.app/Contents/Helpers/CodexBarCLI",
      providers: [.codex], now: now)
    precondition(!unrelated)
    print("PASS agent start, idle timeout, CPU activity and collector exclusion")
    withExtendedLifetime(observer) {}
    print("PASS repeated menu insertion writeback (3000 writes)")
    print("PASS real changes publish exactly once")
    print("PASS independent menu bar and exclusive detail modes persist")
    print("PASS accepted settings survive reload")
    let started = Date()
    let collection = Task { try await ProcessRunner.run("/bin/sleep", arguments: ["10"]) }
    try? await Task.sleep(for: .milliseconds(100))
    collection.cancel()
    do {
      _ = try await collection.value
      preconditionFailure("Cancelled collection must not return a result")
    } catch is CancellationError {
      precondition(Date().timeIntervalSince(started) < 2)
    } catch {
      preconditionFailure("Expected cancellation, got: \(error)")
    }
    print("PASS collection cancellation stops promptly")
    let previewReadings = store.readings
    store.previewRefreshAnimation()
    let previewID = store.animationPreviewID
    store.previewRefreshAnimation()
    precondition(store.animationPreviewID != previewID && store.refreshAnimationActive)
    precondition(!store.refreshing && store.readings.count == previewReadings.count)
    store.preferences.refreshAnimation = .none
    let offPreviewID = store.animationPreviewID
    store.previewRefreshAnimation()
    precondition(store.animationPreviewID == offPreviewID && !store.refreshAnimationActive)
    print("PASS repeated animation preview does not trigger collection")
  }
}
