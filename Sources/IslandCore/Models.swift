import Foundation

public enum Provider: String, CaseIterable, Codable, Identifiable, Sendable {
  // Provider identifiers match CodexBar CLI.
  case codex, openai
  case azureOpenAI = "azureopenai"
  case claude, clinepass, cursor, opencode, opencodego
  case alibabaCodingPlan = "alibaba"
  case alibabaTokenPlan = "alibabatokenplan"
  case qwenCloud = "qwencloud"
  case factory, fireworks, gemini, antigravity, copilot, devin, zai, minimax, manus, kimi, kilo, kiro
  case vertexai, augment, jetbrains, moonshot, amp, t3chat, ollama, synthetic, openrouter, elevenlabs
  case warp, windsurf, zed, perplexity, mimo, doubao, sakana, mistral, deepseek, deepinfra
  case codebuff, crof, venice, commandcode, qoder, stepfun, bedrock, grok, llmproxy
  case abacusai = "abacus"
  case groqcloud = "groq"
  case litellm, deepgram, poe, chutes, neuralwatt, clawrouter, longcat, sub2api, wayfinder, zenmux
  case aiand, zoommate, xai, notion, ibmbob
  public var id: String { rawValue }
  public var name: String {
    Self.displayNames[self] ?? rawValue.prefix(1).uppercased() + rawValue.dropFirst()
  }
  private static let displayNames: [Provider: String] = [
    .codex: "Codex", .openai: "OpenAI", .azureOpenAI: "Azure OpenAI", .claude: "Claude",
    .clinepass: "ClinePass", .opencode: "OpenCode", .opencodego: "OpenCode Go",
    .alibabaCodingPlan: "Alibaba Coding Plan", .alibabaTokenPlan: "Alibaba Token Plan",
    .qwenCloud: "Qwen Cloud", .antigravity: "Antigravity", .copilot: "GitHub Copilot", .vertexai: "Vertex AI",
    .t3chat: "T3 Chat", .openrouter: "OpenRouter", .elevenlabs: "ElevenLabs",
    .deepseek: "DeepSeek", .deepinfra: "DeepInfra", .commandcode: "Command Code",
    .groqcloud: "GroqCloud", .llmproxy: "LLM Proxy", .xai: "xAI", .ibmbob: "IBM BOB"
  ]
  public var supportsLocalCollection: Bool { self == .codex || self == .claude }
  public var supportsCost: Bool { false }
  public var hint: String {
    switch self {
    case .codex: "优先读取本机 Codex 登录；失败时回退到 CodexBar。"
    case .claude: "优先读取本机 Claude 登录；失败时回退到 CodexBar。"
    default: "通过本机安装或捆绑的 CodexBar 采集。"
    }
  }
  public var dashboard: URL {
    let address =
      switch self {
      case .codex: "https://chatgpt.com/codex/settings/usage"
      case .openai: "https://platform.openai.com/usage"
      case .claude: "https://claude.ai/settings/usage"
      case .antigravity: "https://antigravity.google/"
      case .gemini: "https://aistudio.google.com/"
      case .cursor: "https://cursor.com/dashboard"
      case .copilot: "https://github.com/settings/copilot"
      case .qoder: "https://qoder.com/account/usage"
      default: "https://github.com/steipete/CodexBar"
      }
    return URL(string: address)!
  }
  public var defaultColorHex: String {
    switch self {
    case .codex, .openai: "#6BE6BF"
    case .claude, .manus, .venice: "#E89E75"
    case .antigravity, .gemini, .vertexai: "#87B0FF"
    case .copilot, .kiro, .azureOpenAI: "#5F6FEF"
    case .deepseek, .openrouter, .perplexity, .xai: "#3D9CFF"
    case .zai, .qwenCloud, .alibabaCodingPlan, .alibabaTokenPlan: "#F59E0B"
    default: "#28B6A8"
    }
  }
}

public enum ChartStyle: String, CaseIterable, Codable, Identifiable, Sendable {
  case ring, bar, segments, number, sparkline
  public var id: String { rawValue }
  public var title: String {
    switch self {
    case .ring: "圆环"
    case .bar: "进度条"
    case .segments: "分段"
    case .number: "数字"
    case .sparkline: "趋势"
    }
  }
}
public enum Accent: String, CaseIterable, Codable, Identifiable, Sendable {
  case provider, mint, blue, purple, orange, white
  public var id: String { rawValue }
  public var title: String {
    switch self {
    case .provider: "品牌色"
    case .mint: "薄荷绿"
    case .blue: "天空蓝"
    case .purple: "紫罗兰"
    case .orange: "琥珀橙"
    case .white: "纯白"
    }
  }
}
public enum IslandSideVisibility: String, CaseIterable, Codable, Identifiable, Sendable {
  case left, both, right
  public var id: String { rawValue }
  public var title: String {
    switch self {
    case .left: "左侧"
    case .both: "两侧"
    case .right: "右侧"
    }
  }
}
public enum RefreshAnimationStyle: String, CaseIterable, Codable, Identifiable, Sendable {
  case none = "关闭"
  case digitFlip = "数字翻页"
  case meteor = "流星划过"
  case glow = "发光闪烁"
  case sparkle = "呼吸闪点"
  case radar = "雷达扫描"
  case pixels = "像素汇聚"
  case waves = "能量波纹"
  case rain = "数据雨"
  case random = "随机"
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    switch value {
    case "向右扫描", "电路脉冲", "双星环绕", "闪点", "闪电": self = .sparkle
    default:
      guard let style = Self(rawValue: value) else {
        throw DecodingError.dataCorruptedError(
          in: container, debugDescription: "Unknown refresh animation")
      }
      self = style
    }
  }
  public var id: String { rawValue }
}
public enum MusicWaveStyle: String, CaseIterable, Codable, Identifiable, Sendable {
  case off = "关闭"
  case bars = "动画1"
  case shortLines = "动画2"
  case bouncingNotes = "动画3"
  case random = "随机"
  public var id: String { rawValue }
  public var displayName: String {
    switch self {
    case .bars: "条形音频"
    case .shortLines: "短线音频"
    case .bouncingNotes: "音符跳动"
    case .off, .random: rawValue
    }
  }
}
public struct SideConfiguration: Codable, Equatable, Sendable {
  public var provider: Provider
  public var isVisible = true
  private var selectedIDs = ["primary"]
  public var windowIDs: [String] {
    get { selectedIDs }
    set {
      var seen = Set<String>()
      let ids = newValue.filter { !$0.isEmpty && seen.insert($0).inserted }
      selectedIDs = ids.isEmpty ? ["primary"] : ids
    }
  }
  // Compatibility for single-window callers and older configuration edits.
  public var windowID: String {
    get { windowIDs[0] }
    set { windowIDs = [newValue] }
  }
  private var selectedStyles: [ChartStyle] = [.ring]
  public var styles: [ChartStyle] {
    get { selectedStyles }
    set {
      var seen = Set<ChartStyle>()
      let unique = newValue.filter { seen.insert($0).inserted }
      if !unique.isEmpty { selectedStyles = unique }
    }
  }
  public var style: ChartStyle {
    get { styles[0] }
    set { styles = [newValue] }
  }
  public func displayStyles(revealed: Bool, hasQuota: Bool) -> [ChartStyle] {
    if revealed && hasQuota && !styles.contains(.number) {
      return styles + [.number]
    }
    return styles
  }
  public var accent: Accent = .provider
  public var showIcon = true
  public var showName = false
  public init(
    provider: Provider, style: ChartStyle = .ring, windowIDs: [String] = ["primary"]
  ) {
    self.provider = provider
    self.style = style
    self.windowIDs = windowIDs
  }
  public func displayWindowIDs(reading: UsageReading?) -> [String] {
    guard let reading else { return windowIDs }
    let selected = Set(windowIDs)
    let known = reading.windows.map(\.id).filter { selected.contains($0) }
    let knownSet = Set(known)
    return known + windowIDs.filter { !knownSet.contains($0) }
  }
  private enum CodingKeys: String, CodingKey {
    case provider, isVisible, windowID, windowIDs, style, styles, accent, showIcon, showName
  }
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    provider = try c.decode(Provider.self, forKey: .provider)
    isVisible = try c.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
    let legacyID = try c.decodeIfPresent(String.self, forKey: .windowID) ?? "primary"
    let rawStyle = try c.decodeIfPresent(String.self, forKey: .style) ?? "ring"
    style = ChartStyle(rawValue: rawStyle) ?? .number
    if let rawStyles = try c.decodeIfPresent([String].self, forKey: .styles) {
      styles = rawStyles.compactMap(ChartStyle.init(rawValue:))
    }
    accent = try c.decodeIfPresent(Accent.self, forKey: .accent) ?? .provider
    showIcon = try c.decodeIfPresent(Bool.self, forKey: .showIcon) ?? true
    showName = try c.decodeIfPresent(Bool.self, forKey: .showName) ?? false
    if let ids = try c.decodeIfPresent([String].self, forKey: .windowIDs) {
      windowIDs = ids
    } else if rawStyle == "dualPeriod" {
      if provider == .antigravity {
        let prefix = "antigravity-quota-summary-"
        let group = legacyID == "secondary" || legacyID.hasPrefix(prefix + "3p-") ? "3p" : "gemini"
        windowIDs = [prefix + group + "-5h", prefix + group + "-weekly"]
      } else {
        windowIDs =
          ["primary", "secondary"].contains(legacyID) ? ["primary", "secondary"] : [legacyID]
      }
    } else {
      windowIDs = [legacyID]
    }
  }
  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(provider, forKey: .provider)
    try c.encode(isVisible, forKey: .isVisible)
    try c.encode(windowIDs, forKey: .windowIDs)
    try c.encode(style, forKey: .style)
    try c.encode(styles, forKey: .styles)
    try c.encode(accent, forKey: .accent)
    try c.encode(showIcon, forKey: .showIcon)
    try c.encode(showName, forKey: .showName)
  }
}
public enum DetailInteraction: String, CaseIterable, Identifiable, Sendable {
  case click, hover, none
  public var id: String { rawValue }
  public var title: String {
    switch self {
    case .click: "点击时显示详情"
    case .hover: "悬停时显示详情"
    case .none: "不显示详情"
    }
  }
}

public struct IslandProviderLayout: Codable, Equatable, Sendable {
  public var left: [Provider] = []
  public var right: [Provider] = []
  public var configurations: [Provider: SideConfiguration] = [:]
}

public struct Preferences: Codable, Equatable, Sendable {
  public var left = SideConfiguration(
    provider: .claude, style: .ring, windowIDs: ["primary", "secondary"])
  public var right = SideConfiguration(
    provider: .codex, style: .number, windowIDs: ["primary", "secondary"])
  public var enabled: [Provider] = [.claude, .codex]
  public var remaining = true
  public var alwaysShow = true
  public var hoverExpand = true
  public var clickExpand = false
  public var showMenuBarIcon = true
  public var showIsland = true
  public var openDashboardOnLaunch = true
  public var islandSideVisibility: IslandSideVisibility = .both
  private var islandLayout: IslandProviderLayout?
  public var refreshMinutes = 5
  public var sideWidth: Double = 124
  public var screenID = "auto"
  public var verticalOffset: Double = 0
  public var horizontalOffset: Double = 0
  public var alerts = true
  public var warningPercent: Double = 20
  public var criticalPercent: Double = 5
  public var cliPath = ""
  public var notifications = false
  public var celebrateReset = true
  public var absoluteResetTime = true
  public var refreshDigitFlip = true
  public var refreshMeteor = true
  public var refreshAnimation: RefreshAnimationStyle = .random
  public var musicWaveStyle: MusicWaveStyle = .off
  public var providerColors: [String: String] = [:]
  public init() {}
  private enum CodingKeys: String, CodingKey {
    case left, right, enabled, remaining, alwaysShow, hoverExpand, clickExpand, showMenuBarIcon,
      showIsland, openDashboardOnLaunch, islandSideVisibility, islandLayout
    case refreshMinutes, sideWidth, screenID, verticalOffset, horizontalOffset, alerts, warningPercent,
      criticalPercent, cliPath, notifications, celebrateReset, absoluteResetTime,
      refreshDigitFlip, refreshMeteor, refreshAnimation, providerColors,
      musicWaveStyle
  }
  public init(from decoder: Decoder) throws {
    self.init()
    let c = try decoder.container(keyedBy: CodingKeys.self)
    left = try c.decodeIfPresent(SideConfiguration.self, forKey: .left) ?? left
    right = try c.decodeIfPresent(SideConfiguration.self, forKey: .right) ?? right
    enabled = try c.decodeIfPresent([Provider].self, forKey: .enabled) ?? enabled
    remaining = try c.decodeIfPresent(Bool.self, forKey: .remaining) ?? remaining
    alwaysShow = try c.decodeIfPresent(Bool.self, forKey: .alwaysShow) ?? alwaysShow
    hoverExpand = try c.decodeIfPresent(Bool.self, forKey: .hoverExpand) ?? hoverExpand
    clickExpand = try c.decodeIfPresent(Bool.self, forKey: .clickExpand) ?? clickExpand
    showMenuBarIcon = try c.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? showMenuBarIcon
    showIsland = try c.decodeIfPresent(Bool.self, forKey: .showIsland) ?? showIsland
    openDashboardOnLaunch =
      try c.decodeIfPresent(Bool.self, forKey: .openDashboardOnLaunch) ?? openDashboardOnLaunch
    islandSideVisibility =
      try c.decodeIfPresent(IslandSideVisibility.self, forKey: .islandSideVisibility)
      ?? islandSideVisibility
    islandLayout = try c.decodeIfPresent(IslandProviderLayout.self, forKey: .islandLayout)
    refreshMinutes = try c.decodeIfPresent(Int.self, forKey: .refreshMinutes) ?? refreshMinutes
    sideWidth = try c.decodeIfPresent(Double.self, forKey: .sideWidth) ?? sideWidth
    screenID = try c.decodeIfPresent(String.self, forKey: .screenID) ?? screenID
    verticalOffset = try c.decodeIfPresent(Double.self, forKey: .verticalOffset) ?? verticalOffset
    horizontalOffset = try c.decodeIfPresent(Double.self, forKey: .horizontalOffset) ?? horizontalOffset
    alerts = try c.decodeIfPresent(Bool.self, forKey: .alerts) ?? alerts
    warningPercent = try c.decodeIfPresent(Double.self, forKey: .warningPercent) ?? warningPercent
    criticalPercent =
      try c.decodeIfPresent(Double.self, forKey: .criticalPercent) ?? criticalPercent
    cliPath = try c.decodeIfPresent(String.self, forKey: .cliPath) ?? cliPath
    notifications = try c.decodeIfPresent(Bool.self, forKey: .notifications) ?? notifications
    celebrateReset = try c.decodeIfPresent(Bool.self, forKey: .celebrateReset) ?? celebrateReset
    absoluteResetTime =
      try c.decodeIfPresent(Bool.self, forKey: .absoluteResetTime) ?? absoluteResetTime
    refreshDigitFlip =
      try c.decodeIfPresent(Bool.self, forKey: .refreshDigitFlip) ?? refreshDigitFlip
    refreshMeteor = try c.decodeIfPresent(Bool.self, forKey: .refreshMeteor) ?? refreshMeteor
    refreshAnimation =
      try c.decodeIfPresent(RefreshAnimationStyle.self, forKey: .refreshAnimation)
      ?? (refreshDigitFlip ? .digitFlip : refreshMeteor ? .meteor : .sparkle)
    providerColors = try c.decodeIfPresent([String: String].self, forKey: .providerColors) ?? providerColors
    let legacyMusic = try decoder.container(keyedBy: LegacyMusicKeys.self)
    let wasEnabled = try legacyMusic.decodeIfPresent(Bool.self, forKey: .musicWaveEnabled)
    if wasEnabled != false, let style = try c.decodeIfPresent(String.self, forKey: .musicWaveStyle) {
      switch style {
      case "跃动音符", "节拍涟漪", "条形音频可视化", "条形音频":
        musicWaveStyle = .bars
      case "短线音频":
        musicWaveStyle = .shortLines
      case "音符跳动":
        musicWaveStyle = .bouncingNotes
      default:
        musicWaveStyle = MusicWaveStyle(rawValue: style) ?? .off
      }
    }
    normalize()
  }
  private enum LegacyMusicKeys: String, CodingKey {
    case musicWaveEnabled
  }

  public var detailEntryCount: Int {
    [clickExpand, hoverExpand, showMenuBarIcon].filter { $0 }.count
  }
  private var resolvedIslandLayout: IslandProviderLayout {
    if let islandLayout { return islandLayout }
    var layout = IslandProviderLayout()
    for side in [left, right] {
      if layout.configurations[side.provider] == nil || side.isVisible {
        layout.configurations[side.provider] = side
      }
    }
    if left.isVisible { layout.left = [left.provider] }
    if right.isVisible && !layout.left.contains(right.provider) { layout.right = [right.provider] }
    if islandSideVisibility == .left {
      layout.left += layout.right
      layout.right = []
    } else if islandSideVisibility == .right {
      layout.right = layout.left + layout.right
      layout.left = []
    }
    return layout
  }

  public var islandLeftProviders: [Provider] { resolvedIslandLayout.left.filter { enabled.contains($0) } }
  public var islandRightProviders: [Provider] { resolvedIslandLayout.right.filter { enabled.contains($0) } }

  public func islandConfiguration(for provider: Provider) -> SideConfiguration {
    resolvedIslandLayout.configurations[provider] ?? SideConfiguration(provider: provider)
  }

  public mutating func setIslandConfiguration(_ configuration: SideConfiguration) {
    var layout = resolvedIslandLayout
    layout.configurations[configuration.provider] = configuration
    islandLayout = layout
  }

  @discardableResult
  public mutating func placeIslandProvider(
    _ provider: Provider, on side: IslandSideVisibility?, before target: Provider? = nil
  ) -> Bool {
    guard enabled.contains(provider), side != .both, provider != target else { return false }
    var layout = resolvedIslandLayout
    layout.left.removeAll { $0 == provider }
    layout.right.removeAll { $0 == provider }
    if side == .left {
      layout.left.insert(provider, at: target.flatMap { layout.left.firstIndex(of: $0) } ?? layout.left.count)
    } else if side == .right {
      layout.right.insert(provider, at: target.flatMap { layout.right.firstIndex(of: $0) } ?? layout.right.count)
    }
    islandLayout = layout
    return true
  }

  public mutating func swapIslandSides() {
    var layout = resolvedIslandLayout
    let left = layout.left
    layout.left = layout.right
    layout.right = left
    islandLayout = layout
  }

  public var visibleIslandSides: [SideConfiguration] {
    (islandLeftProviders + islandRightProviders).map { islandConfiguration(for: $0) }
  }
  public var islandHeadlinePlacement: IslandSideVisibility? {
    let hasLeft = !islandLeftProviders.isEmpty
    let hasRight = !islandRightProviders.isEmpty
    if hasLeft && hasRight { return .both }
    if hasLeft { return .left }
    if hasRight { return .right }
    return nil
  }
  public var isIslandVisible: Bool { showIsland && islandHeadlinePlacement != nil }
  public var detailInteraction: DetailInteraction {
    get { hoverExpand ? .hover : (clickExpand ? .click : .none) }
    set {
      clickExpand = newValue == .click
      hoverExpand = newValue == .hover
    }
  }
  public var providersToFetch: [Provider] {
    Provider.allCases
      .filter { enabled.contains($0) }
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }
  public func colorHex(for provider: Provider) -> String {
    providerColors[provider.rawValue] ?? provider.defaultColorHex
  }
  public mutating func setColorHex(_ value: String, for provider: Provider) {
    let normalized = Self.normalizedHex(value)
    if normalized == provider.defaultColorHex {
      providerColors.removeValue(forKey: provider.rawValue)
    } else {
      providerColors[provider.rawValue] = normalized
    }
  }
  public static func normalizedHex(_ value: String) -> String {
    let digits = value.trimmingCharacters(in: .whitespacesAndNewlines)
      .uppercased()
      .replacingOccurrences(of: "#", with: "")
    guard digits.count == 6, digits.allSatisfy({ $0.isHexDigit }) else { return "#28B6A8" }
    return "#\(digits)"
  }
  public mutating func normalize() {
    // Legacy configurations could enable both triggers. Prefer their hover choice.
    if hoverExpand { clickExpand = false }
    // Hidden island entry points are unreachable; preserve the menu bar route.
    refreshMinutes = [0, 1, 5, 15, 30].contains(refreshMinutes) ? refreshMinutes : 5
    sideWidth = min(180, max(104, sideWidth.isFinite ? sideWidth : 124))
    verticalOffset = min(80, max(0, verticalOffset.isFinite ? verticalOffset : 0))
    horizontalOffset = min(1000, max(-1000, horizontalOffset.isFinite ? horizontalOffset : 0))
    warningPercent = min(50, max(5, warningPercent.isFinite ? warningPercent : 20))
    criticalPercent = min(50, max(1, criticalPercent.isFinite ? criticalPercent : 5))
    // The island can only display providers that have been explicitly enabled.
    // Preserve legacy side selections by enabling them during migration.
    if islandLayout == nil {
      enabled.append(left.provider)
      enabled.append(right.provider)
    }
    enabled = Provider.allCases.filter { enabled.contains($0) }
    if var layout = islandLayout {
      var seen = Set<Provider>()
      layout.left = layout.left.filter { enabled.contains($0) && seen.insert($0).inserted }
      layout.right = layout.right.filter { enabled.contains($0) && seen.insert($0).inserted }
      islandLayout = layout
    }
    if !isIslandVisible { showMenuBarIcon = true }
    providerColors = providerColors.reduce(into: [:]) { colors, entry in
      guard let provider = Provider(rawValue: entry.key) else { return }
      let color = Self.normalizedHex(entry.value)
      if color != provider.defaultColorHex { colors[provider.rawValue] = color }
    }
  }
}

public struct QuotaWindow: Codable, Identifiable, Equatable, Sendable {
  public var id: String
  public var title: String
  public var usedPercent: Double?
  public var minutes: Int?
  public var resetsAt: Date?
  public var resetDescription: String?
  public var nextRegenPercent: Double?
  public var remainingTokens: Double?
  public init(
    id: String, title: String, usedPercent: Double?, minutes: Int? = nil, resetsAt: Date? = nil,
    resetDescription: String? = nil, remainingTokens: Double? = nil, nextRegenPercent: Double? = nil
  ) {
    self.id = id
    self.title = title
    self.usedPercent = usedPercent
    self.minutes = minutes
    self.resetsAt = resetsAt
    self.resetDescription = resetDescription
    self.remainingTokens = remainingTokens
    self.nextRegenPercent = nextRegenPercent
  }
  public var remainingPercent: Double? {
    usedPercent.flatMap { $0.isFinite ? min(100, max(0, 100 - $0)) : nil }
  }
  public func percent(remaining: Bool) -> Double? {
    remaining ? remainingPercent : usedPercent.flatMap { $0.isFinite ? min(100, max(0, $0)) : nil }
  }
}
public struct ResetCredit: Codable, Sendable {
  public var expiresAt: Date?
  public init(expiresAt: Date?) { self.expiresAt = expiresAt }
}
public struct UsageReading: Codable, Sendable {
  public var provider: Provider
  public var windows: [QuotaWindow]
  public var updatedAt: Date
  public var source: String
  public var plan: String?
  public var accountEmail: String?
  public var credits: Double?
  public var error: String?
  public var resetCredits: [ResetCredit]?
  public init(
    provider: Provider, windows: [QuotaWindow] = [], updatedAt: Date = Date(), source: String,
    plan: String? = nil, credits: Double? = nil, error: String? = nil
  ) {
    self.provider = provider
    self.windows = windows
    self.updatedAt = updatedAt
    self.source = source
    self.plan = plan
    self.credits = credits
    self.error = error
  }
  public func window(_ id: String) -> QuotaWindow? { windows.first { $0.id == id } }
  public func stale(now: Date = Date(), refreshMinutes: Int) -> Bool {
    error != nil || now.timeIntervalSince(updatedAt) > Double(refreshMinutes * 120)
  }
}
public struct Sample: Codable, Identifiable, Sendable {
  public var provider: Provider
  public var windowID: String
  public var date: Date
  public var used: Double
  public var id: String { "\(provider.rawValue)-\(windowID)-\(date.timeIntervalSince1970)" }
  public init(provider: Provider, windowID: String, date: Date, used: Double) {
    self.provider = provider
    self.windowID = windowID
    self.date = date
    self.used = used
  }
}
public struct DailyCost: Codable, Identifiable, Sendable {
  public var date: String
  public var totalTokens: Int?
  public var totalCost: Double?
  public var id: String { date }
}
public struct CostReading: Codable, Sendable {
  public var provider: String
  public var sessionTokens: Int?
  public var sessionCostUSD: Double?
  public var last30DaysTokens: Int?
  public var last30DaysCostUSD: Double?
  public var daily: [DailyCost]?
}

public enum IslandGeometry {
  public static func menuHeight(safeTop: Double, visibleDelta: Double, statusBar: Double) -> Double
  {
    let measured = visibleDelta - 1
    if measured > 0 { return safeTop > 0 ? min(measured, safeTop) : min(measured, 48) }
    return safeTop > 0 ? safeTop : max(24, statusBar)
  }

  /// Returns the screen-local leading edge for an Island whose internal notch
  /// spacer must begin at `notchLeft` when the user has not applied an offset.
  /// Keeping this edge as the source of truth avoids centering arithmetic that
  /// can introduce a half-pixel mismatch on asymmetric, one-sided layouts.
  public static func islandLeft(
    notchLeft: Double,
    leadingContentWidth: Double,
    horizontalOffset: Double,
    screenWidth: Double,
    islandWidth: Double,
    edgeInset: Double = 24
  ) -> Double {
    let desired = notchLeft - leadingContentWidth + horizontalOffset
    let minimum = edgeInset
    let maximum = screenWidth - islandWidth - edgeInset
    // Match the previous centered fallback when the Island is wider than the
    // usable screen width. Normal layout constrains it before reaching here.
    guard maximum >= minimum else { return (screenWidth - islandWidth) / 2 }
    return min(maximum, max(minimum, desired))
  }
}
