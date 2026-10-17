import AppKit
import IslandCore
import SwiftUI
import UserNotifications

enum DemoPreset: String, CaseIterable, Identifiable {
  case full = "100%"
  case half = "50%"
  case quarter = "25%"
  case warning = "橙色 · 15%"
  case critical = "红色 · 3%"
  case random = "随机数据"
  var id: String { rawValue }
  var usesRandomData: Bool { self == .random }
  var remaining: Double {
    switch self {
    case .full: 100
    case .half: 50
    case .quarter: 25
    case .warning: 15
    case .critical: 3
    case .random: 50
    }
  }
}

@MainActor
final class AppStore: ObservableObject {
  static let shared = AppStore()
  @Published private(set) var storedPreferences: Preferences
  var preferences: Preferences {
    get { storedPreferences }
    set {
      var corrected = newValue
      corrected.normalize()
      // MenuBarExtra writes its insertion binding during scene reconciliation, even
      // when unchanged. Reject no-op writes BEFORE @Published sends objectWillChange.
      guard corrected != storedPreferences else { return }
      storedPreferences = corrected
      if let data = try? JSONEncoder().encode(corrected) {
        defaults.set(data, forKey: "preferences.v1")
      }
    }
  }
  @Published var readings: [Provider: UsageReading] = [:]
  @Published var samples: [Sample] = []
  @Published var dashboardOpen = false
  @Published var costs: [Provider: CostReading] = [:]
  @Published var costErrors: [Provider: String] = [:]
  @Published var refreshing = false {
    willSet { if newValue && !refreshAnimationActive { chooseRefreshAnimation() } }
  }
  @Published var refreshingCost = false {
    willSet { if newValue && !refreshAnimationActive { chooseRefreshAnimation() } }
  }
  @Published private(set) var animationPreviewActive = false
  @Published private(set) var animationPreviewID = UUID()
  private var animationPreviewTask: Task<Void, Never>?
  var refreshAnimationActive: Bool {
    preferences.refreshAnimation != .none && (refreshing || refreshingCost || animationPreviewActive)
  }

  @Published private(set) var randomRefreshAnimation: RefreshAnimationStyle = .sparkle
  var effectiveRefreshAnimation: RefreshAnimationStyle {
    preferences.refreshAnimation == .random ? randomRefreshAnimation : preferences.refreshAnimation
  }

  private func chooseRefreshAnimation() {
    guard preferences.refreshAnimation == .random else { return }
    randomRefreshAnimation = RefreshAnimationStyle.allCases.filter {
      $0 != .none && $0 != .random
    }.randomElement() ?? .sparkle
  }

  func previewRefreshAnimation() {
    animationPreviewTask?.cancel()
    guard preferences.refreshAnimation != .none else {
      animationPreviewActive = false
      return
    }
    chooseRefreshAnimation()
    animationPreviewID = UUID()
    animationPreviewActive = true
    animationPreviewTask = Task { [weak self] in
      do { try await Task.sleep(for: .seconds(4)) } catch { return }
      self?.animationPreviewActive = false
    }
  }
  @Published var nextRefresh: Date?
  @Published var demoMode = false
  @Published private(set) var demoPreset: DemoPreset = .full
  @Published var notice: String?
  @Published private(set) var resetEvent = UUID()
  @Published private(set) var agentActive = false
  private let activityMonitor = AgentActivityMonitor()
  private var lastRefreshFinished: Date?
  var effectiveRefreshMinutes: Int {
    preferences.refreshMinutes == 0 ? (agentActive ? 1 : 5) : preferences.refreshMinutes
  }
  var refreshDescription: String {
    preferences.refreshMinutes == 0
      ? "自适应 · \(agentActive ? "活跃" : "空闲") · \(effectiveRefreshMinutes) 分钟"
      : "\(preferences.refreshMinutes) 分钟"
  }
  private var dataGeneration = UUID()
  private var refreshTask: Task<Void, Never>?
  // Separate from UI flags: demo switching must not release an in-flight collector.
  private var collectionBusy = false

  private func acquireCollection(generation: UUID) async -> Bool {
    while collectionBusy {
      do { try await Task.sleep(for: .milliseconds(50)) } catch { return false }
      guard generation == dataGeneration, !demoMode else { return false }
    }
    guard generation == dataGeneration, !demoMode, !Task.isCancelled else { return false }
    collectionBusy = true
    return true
  }
  private var notified: [String: Int] = [:]
  private var lastCostRefresh: Date?
  private let directory: URL
  private let defaults: UserDefaults
  private var liveReadings: [Provider: UsageReading] = [:]
  private var liveSamples: [Sample] = []

  init(defaults: UserDefaults = .standard, directory: URL? = nil) {
    self.defaults = defaults
    demoPreset = defaults.string(forKey: "demoPreset").flatMap(DemoPreset.init(rawValue:)) ?? .full
    let saved = defaults.data(forKey: "preferences.v1")
    var prefs =
      saved.flatMap { try? JSONDecoder().decode(Preferences.self, from: $0) } ?? Preferences()
    prefs.normalize()
    storedPreferences = prefs
    self.directory =
      directory
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("IsLandToken")
    if let data = try? Data(contentsOf: self.directory.appendingPathComponent("history.json")),
      let value = try? JSONDecoder().decode([Sample].self, from: data)
    {
      samples = value
    }
    if let data = try? Data(contentsOf: self.directory.appendingPathComponent("readings.json")),
      let value = try? JSONDecoder().decode([UsageReading].self, from: data)
    {
      readings = Dictionary(value.map { ($0.provider, $0) }, uniquingKeysWith: { _, new in new })
    }
  }
  func start() { schedule(immediate: true) }
  func schedule(immediate: Bool = false) {
    refreshTask?.cancel()
    guard !demoMode else {
      nextRefresh = nil
      return
    }
    if lastRefreshFinished == nil { lastRefreshFinished = Date() }
    refreshTask = Task { [weak self] in
      guard let self else { return }
      if immediate {
        await self.refresh()
        guard !Task.isCancelled, !self.demoMode else { return }
        await self.refreshCosts()
      }
      while !Task.isCancelled {
        let adaptive = self.preferences.refreshMinutes == 0
        if adaptive {
          let active = await self.activityMonitor.isActive(
            providers: self.preferences.providersToFetch)
          guard !Task.isCancelled, !self.demoMode else { return }
          self.agentActive = active
        }
        let interval = Double(self.effectiveRefreshMinutes * 60)
        let due = (self.lastRefreshFinished ?? Date()).addingTimeInterval(interval)
        self.nextRefresh = due
        let delay = max(0, due.timeIntervalSinceNow)
        do { try await Task.sleep(for: .seconds(adaptive ? min(15, delay) : delay)) } catch {
          return
        }
        guard !Task.isCancelled, !self.demoMode else { return }
        if Date() >= due {
          if self.refreshing {
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
          } else {
            await self.refresh()
            guard !Task.isCancelled, !self.demoMode else { return }
            await self.refreshCosts()
          }
        }
      }
    }
  }
  func refresh() async {
    guard !refreshing, !demoMode else { return }
    refreshing = true
    let generation = dataGeneration
    defer { if generation == dataGeneration { refreshing = false } }
    guard await acquireCollection(generation: generation) else { return }
    defer { collectionBusy = false }
    let settings = preferences
    // Run provider collectors sequentially under the shared usage/cost lock.
    let providers = settings.providersToFetch
    var observedSamples = Set(samples.map(\.id))
    for provider in providers {
      guard generation == dataGeneration, !Task.isCancelled else { return }
      let reading: UsageReading
      do {
        reading = try await UsageService.fetch(provider, preferences: settings)
      } catch {
        reading = UsageReading(
          provider: provider, source: "未连接",
          error: (error as? UsageError)?.localizedDescription ?? "采集失败，请检查平台配置。")
      }
      guard generation == dataGeneration, !Task.isCancelled else { return }
      if reading.error != nil, var previous = readings[reading.provider] {
        previous.error = reading.error
        readings[reading.provider] = previous
      } else {
        if preferences.celebrateReset && didReset(old: readings[reading.provider], new: reading) {
          resetEvent = UUID()
        }
        readings[reading.provider] = reading
      }
      if reading.error == nil {
        for window in reading.windows {
          if let used = window.usedPercent, used.isFinite {
            // Cached CLI responses must not create fake new historical observations.
            let sample = Sample(
              provider: reading.provider, windowID: window.id, date: reading.updatedAt,
              used: used)
            if observedSamples.insert(sample.id).inserted { samples.append(sample) }
          }
        }
        alertIfNeeded(reading)
      }
    }
    guard generation == dataGeneration, !Task.isCancelled else { return }
    let retentionCutoff = Date().addingTimeInterval(-30 * 86400)
    samples = Array(
      samples.filter { $0.date > retentionCutoff }.sorted {
        $0.date < $1.date
      }.suffix(60000))
    persist()
    lastRefreshFinished = Date()
    refreshing = false
  }
  /// Refreshes one provider from its dedicated settings page without collecting every enabled provider.
  func refreshProvider(_ provider: Provider) async {
    guard !refreshing, !demoMode else { return }
    refreshing = true
    let generation = dataGeneration
    defer { if generation == dataGeneration { refreshing = false } }
    guard await acquireCollection(generation: generation) else { return }
    defer { collectionBusy = false }
    let settings = preferences
    let reading: UsageReading
    do {
      reading = try await UsageService.fetch(provider, preferences: settings)
    } catch {
      reading = UsageReading(
        provider: provider, source: "未连接",
        error: (error as? UsageError)?.localizedDescription ?? "采集失败，请检查平台配置。")
    }
    guard generation == dataGeneration, !Task.isCancelled else { return }
    if reading.error != nil, var previous = readings[provider] {
      previous.error = reading.error
      readings[provider] = previous
    } else {
      if preferences.celebrateReset && didReset(old: readings[provider], new: reading) {
        resetEvent = UUID()
      }
      readings[provider] = reading
    }
    if reading.error == nil {
      var observed = Set(samples.map(\.id))
      for window in reading.windows where window.usedPercent?.isFinite == true {
        let sample = Sample(
          provider: provider, windowID: window.id, date: reading.updatedAt,
          used: window.usedPercent!)
        if observed.insert(sample.id).inserted { samples.append(sample) }
      }
      alertIfNeeded(reading)
    }
    let cutoff = Date().addingTimeInterval(-30 * 86400)
    samples = Array(samples.filter { $0.date > cutoff }.sorted { $0.date < $1.date }.suffix(60000))
    persist()
    lastRefreshFinished = Date()
  }
  private func didReset(old: UsageReading?, new: UsageReading) -> Bool {
    guard let old else { return false }
    for window in new.windows {
      guard let previous = old.window(window.id) else { continue }
      let resetTimeAdvanced =
        previous.resetsAt.map { $0 <= Date() && window.resetsAt.map { $0 > Date() } ?? false }
        ?? false
      let quotaRecovered = (previous.usedPercent ?? 0) - (window.usedPercent ?? 0) >= 35
      if resetTimeAdvanced || quotaRecovered { return true }
    }
    return false
  }
  func refreshCosts() async {
    guard !refreshingCost, !demoMode else { return }
    if let lastCostRefresh, Date().timeIntervalSince(lastCostRefresh) < 60 { return }
    refreshingCost = true
    let generation = dataGeneration
    defer { if generation == dataGeneration { refreshingCost = false } }
    guard await acquireCollection(generation: generation) else { return }
    defer { collectionBusy = false }
    lastCostRefresh = Date()
    costs.removeAll()
    costErrors = Dictionary(
      uniqueKeysWithValues: preferences.providersToFetch.map {
        ($0, "本地采集当前不提供 Token 与费用记录。")
      })
    refreshingCost = false
  }
  func refreshCost(for provider: Provider) async {
    guard !demoMode else { return }
    costs.removeValue(forKey: provider)
    costErrors[provider] = "本地采集当前不提供 Token 与费用记录。"
  }
  func history(provider: Provider, windowID: String) -> [Sample] {
    var recent: [Sample] = []
    recent.reserveCapacity(144)
    for sample in samples.reversed() {
      guard sample.provider == provider && sample.windowID == windowID else { continue }
      recent.append(sample)
      if recent.count == 144 { break }
    }
    return Array(recent.reversed())
  }
  func setDemo(_ value: Bool) {
    guard value != demoMode else { return }
    // Invalidate suspended requests before replacing the active data set.
    dataGeneration = UUID()
    refreshTask?.cancel()
    refreshTask = nil
    refreshing = false
    refreshingCost = false
    nextRefresh = nil
    lastCostRefresh = nil
    if value {
      liveReadings = readings
      liveSamples = samples
      demoMode = true
      regenerateDemo()
    } else {
      demoMode = false
      readings = liveReadings
      samples = liveSamples
      liveReadings = [:]
      liveSamples = []
      schedule(immediate: true)
    }
  }
  func setDemoPreset(_ preset: DemoPreset) {
    demoPreset = preset
    defaults.set(preset.rawValue, forKey: "demoPreset")
    if demoMode { regenerateDemo() }
  }
  var demoTint: Color? {
    guard demoMode else { return nil }
    switch demoPreset {
    case .warning: return .orange
    case .critical: return .red
    default: return nil
    }
  }
  private func regenerateDemo() {
    let generatedAt = Date()
    var demoReadings: [Provider: UsageReading] = [:]
    var demoSamples: [Sample] = []
    demoReadings.reserveCapacity(Provider.allCases.count)
    demoSamples.reserveCapacity(
      Provider.allCases.reduce(0) { $0 + ($1 == .antigravity ? 6 : 2) } * 36)
    for provider in Provider.allCases {
      let windowCount = provider == .antigravity ? 6 : 2
      var randomRemaining: [Double] = []
      if demoPreset.usesRandomData {
        randomRemaining.reserveCapacity(windowCount)
        while randomRemaining.count < windowCount {
          let value = Double(Int.random(in: 3...97))
          if !randomRemaining.contains(value) { randomRemaining.append(value) }
        }
      }
      func remaining(at index: Int) -> Double {
        demoPreset.usesRandomData ? randomRemaining[index] : demoPreset.remaining
      }
      var windows = [
        QuotaWindow(
          id: "primary", title: provider == .antigravity ? "Gemini Pro" : "5 小时额度",
          usedPercent: 100 - remaining(at: 0), minutes: 300,
          resetsAt: generatedAt.addingTimeInterval(7200)),
        QuotaWindow(
          id: "secondary", title: provider == .antigravity ? "Claude / GPT" : "7 天额度",
          usedPercent: 100 - remaining(at: 1), minutes: 10080,
          resetsAt: generatedAt.addingTimeInterval(230000)),
      ]
      if provider == .antigravity {
        for group in ["gemini", "3p"] {
          let index = group == "gemini" ? 2 : 4
          windows.append(contentsOf: [
            QuotaWindow(
              id: "antigravity-quota-summary-\(group)-5h", title: "5 小时额度",
              usedPercent: 100 - remaining(at: index),
              minutes: 300, resetsAt: generatedAt.addingTimeInterval(7200)),
            QuotaWindow(
              id: "antigravity-quota-summary-\(group)-weekly", title: "7 天额度",
              usedPercent: 100 - remaining(at: index + 1),
              minutes: 10080, resetsAt: generatedAt.addingTimeInterval(230000)),
          ])
        }
      }
      demoReadings[provider] = UsageReading(
        provider: provider, windows: windows, source: "演示数据", plan: "DEMO")
      for window in windows {
        guard let used = window.usedPercent else { continue }
        let trendStep = demoPreset.usesRandomData ? Double.random(in: 0.35...1.05) : 0.7
        for n in 0..<36 {
          demoSamples.append(
            Sample(
              provider: provider, windowID: window.id,
              date: generatedAt.addingTimeInterval(Double(n - 35) * 300),
              used: max(0, used - Double(35 - n) * trendStep)))
        }
      }
    }
    readings = demoReadings
    samples = demoSamples
  }
  func requestNotifications() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
      granted, _ in
      Task { @MainActor in
        self.preferences.notifications = granted
        if !granted { self.notice = "通知未获授权，可在系统设置 → 通知中开启。" }
      }
    }
  }
  private func alertIfNeeded(_ reading: UsageReading) {
    guard preferences.alerts, preferences.notifications,
      !reading.stale(refreshMinutes: effectiveRefreshMinutes)
    else { return }
    for window in reading.windows {
      guard let remaining = window.remainingPercent else { continue }
      let level =
        remaining <= preferences.criticalPercent
        ? 2 : remaining <= preferences.warningPercent ? 1 : 0
      let key = reading.provider.rawValue + window.id
      let prior = notified[key] ?? 0
      notified[key] = level
      guard level > prior else { continue }
      let content = UNMutableNotificationContent()
      content.title = T("%@ 额度提醒", reading.provider.name)
      content.body = T(
        "%@剩余 %d%%，请留意重置时间。", UserFacingText.quotaTitle(window.title), Int(remaining))
      UNUserNotificationCenter.current().add(
        UNNotificationRequest(identifier: key, content: content, trigger: nil))
    }
  }
  private func persist() {
    guard !demoMode else { return }
    do {
      try FileManager.default.createDirectory(
        at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
      try JSONEncoder().encode(samples).write(
        to: directory.appendingPathComponent("history.json"), options: .atomic)
      try JSONEncoder().encode(Array(readings.values)).write(
        to: directory.appendingPathComponent("readings.json"), options: .atomic)
    } catch { notice = "本地历史保存失败，本次数据仍可查看。" }
  }
  func exportHistory() {
    let panel = NSSavePanel()
    panel.nameFieldStringValue =
      demoMode ? "IsLandToken-DEMO-history.csv" : "IsLandToken-history.csv"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    let formatter = ISO8601DateFormatter()
    let text =
      "provider,window,time,used_percent,remaining_percent\n"
      + samples.map {
        "\($0.provider.rawValue),\(csvField($0.windowID)),\(formatter.string(from: $0.date)),\($0.used),\(min(100, max(0, 100 - $0.used)))"
      }.joined(separator: "\n")
    do { try text.write(to: url, atomically: true, encoding: .utf8) } catch {
      notice = "导出失败：\(error.localizedDescription)"
    }
  }
  private func csvField(_ value: String) -> String {
    let safe =
      ["=", "+", "-", "@", "\t", "\r"].contains(where: { value.hasPrefix($0) })
      ? "'" + value : value
    return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
  }
}
