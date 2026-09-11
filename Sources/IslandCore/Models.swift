import Foundation

public enum Provider: String, CaseIterable, Codable, Identifiable, Sendable {
  case codex, claude, antigravity, gemini, cursor, copilot, windsurf, kiro, openrouter, deepseek,
    ollama, opencode
  public var id: String { rawValue }
  public var name: String {
    switch self {
    case .codex: "Codex"
    case .claude: "Claude"
    case .antigravity: "Antigravity"
    case .gemini: "Gemini"
    case .cursor: "Cursor"
    case .copilot: "GitHub Copilot"
    case .windsurf: "Windsurf"
    case .kiro: "Kiro"
    case .openrouter: "OpenRouter"
    case .deepseek: "DeepSeek"
    case .ollama: "Ollama"
    case .opencode: "OpenCode"
    }
  }
  public var supportsDirect: Bool { self == .codex || self == .claude }
  public var supportsCost: Bool {
    [.codex, .claude, .antigravity, .cursor, .opencode].contains(self)
  }
  public var hint: String {
    switch self {
    case .codex: "先在 Codex 登录；支持本地 OAuth 和 CodexBar。"
    case .claude: "先运行 claude 登录；支持凭据文件、钥匙串和 CodexBar。"
    case .antigravity: "在 Antigravity 登录并保持运行，或在 CodexBar 配置 Google 账号。"
    default: "在 CodexBar 中完成此平台的登录与数据源配置。"
    }
  }
  public var dashboard: URL {
    let address =
      switch self {
      case .codex: "https://chatgpt.com/codex/settings/usage"
      case .claude: "https://claude.ai/settings/usage"
      case .antigravity: "https://antigravity.google/"
      case .gemini: "https://aistudio.google.com/"
      case .cursor: "https://cursor.com/dashboard"
      case .copilot: "https://github.com/settings/copilot"
      default: "https://github.com/steipete/CodexBar"
      }
    return URL(string: address)!
  }
}

public enum ChartStyle: String, CaseIterable, Codable, Identifiable, Sendable {
  case ring, bar, segments, number, sparkline, dualPeriod
  public var id: String { rawValue }
  public var title: String {
    switch self {
    case .ring: "圆环"
    case .bar: "进度条"
    case .segments: "分段"
    case .number: "数字"
    case .sparkline: "趋势"
    case .dualPeriod: "5h / 周"
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
  case scan = "向右扫描"
  case digitFlip = "数字翻页"
  case meteor = "流星划过"
  case glow = "发光闪烁"
  case sparkle = "闪点"
  public var id: String { rawValue }
}
public struct SideConfiguration: Codable, Equatable, Sendable {
  public var provider: Provider
  public var windowID = "primary"
  public var style: ChartStyle = .ring
  public var accent: Accent = .provider
  public var showIcon = true
  public var showName = false
  public init(provider: Provider, style: ChartStyle = .ring) {
    self.provider = provider
    self.style = style
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

public struct Preferences: Codable, Equatable, Sendable {
  public var left = SideConfiguration(provider: .codex)
  public var right = SideConfiguration(provider: .claude, style: .bar)
  public var enabled: [Provider] = [.codex, .claude, .antigravity]
  public var remaining = true
  public var alwaysShow = true
  public var hoverExpand = false
  public var clickExpand = true
  public var showMenuBarIcon = true
  public var showIsland = true
  public var islandSideVisibility: IslandSideVisibility = .both
  public var refreshMinutes = 5
  public var sideWidth: Double = 124
  public var screenID = "auto"
  public var verticalOffset: Double = 0
  public var alerts = true
  public var warningPercent: Double = 20
  public var criticalPercent: Double = 5
  public var source = "auto"
  public var cliPath = ""
  public var notifications = false
  public var celebrateReset = true
  public var absoluteResetTime = false
  public var refreshDigitFlip = true
  public var refreshMeteor = true
  public var refreshAnimation: RefreshAnimationStyle = .scan
  public init() {}
  private enum CodingKeys: String, CodingKey {
    case left, right, enabled, remaining, alwaysShow, hoverExpand, clickExpand, showMenuBarIcon,
      showIsland, islandSideVisibility
    case refreshMinutes, sideWidth, screenID, verticalOffset, alerts, warningPercent,
      criticalPercent, source, cliPath, notifications, celebrateReset, absoluteResetTime,
      refreshDigitFlip, refreshMeteor, refreshAnimation
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
    islandSideVisibility =
      try c.decodeIfPresent(IslandSideVisibility.self, forKey: .islandSideVisibility)
      ?? islandSideVisibility
    refreshMinutes = try c.decodeIfPresent(Int.self, forKey: .refreshMinutes) ?? refreshMinutes
    sideWidth = try c.decodeIfPresent(Double.self, forKey: .sideWidth) ?? sideWidth
    screenID = try c.decodeIfPresent(String.self, forKey: .screenID) ?? screenID
    verticalOffset = try c.decodeIfPresent(Double.self, forKey: .verticalOffset) ?? verticalOffset
    alerts = try c.decodeIfPresent(Bool.self, forKey: .alerts) ?? alerts
    warningPercent = try c.decodeIfPresent(Double.self, forKey: .warningPercent) ?? warningPercent
    criticalPercent =
      try c.decodeIfPresent(Double.self, forKey: .criticalPercent) ?? criticalPercent
    source = try c.decodeIfPresent(String.self, forKey: .source) ?? source
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
      ?? (refreshDigitFlip ? .digitFlip : refreshMeteor ? .meteor : .scan)
    normalize()
  }
  public var detailEntryCount: Int {
    [clickExpand, hoverExpand, showMenuBarIcon].filter { $0 }.count
  }
  public var detailInteraction: DetailInteraction {
    get { hoverExpand ? .hover : (clickExpand ? .click : .none) }
    set {
      clickExpand = newValue == .click
      hoverExpand = newValue == .hover
    }
  }
  public var providersToFetch: [Provider] {
    Provider.allCases.filter { enabled.contains($0) || $0 == left.provider || $0 == right.provider }
  }
  public mutating func normalize() {
    // Legacy configurations could enable both triggers. Prefer their hover choice.
    if hoverExpand { clickExpand = false }
    // Hidden island entry points are unreachable; preserve the menu bar route.
    if !showIsland { showMenuBarIcon = true }
    refreshMinutes = [0, 1, 5, 15, 30].contains(refreshMinutes) ? refreshMinutes : 5
    sideWidth = min(180, max(104, sideWidth.isFinite ? sideWidth : 124))
    verticalOffset = min(80, max(0, verticalOffset.isFinite ? verticalOffset : 0))
    warningPercent = min(50, max(5, warningPercent.isFinite ? warningPercent : 20))
    criticalPercent = min(warningPercent, max(1, criticalPercent.isFinite ? criticalPercent : 5))
    if !["auto", "codexbar", "direct"].contains(source) { source = "auto" }
  }
}

public struct QuotaWindow: Codable, Identifiable, Equatable, Sendable {
  public var id: String
  public var title: String
  public var usedPercent: Double?
  public var minutes: Int?
  public var resetsAt: Date?
  public var resetDescription: String?
  public var remainingTokens: Double?
  public init(
    id: String, title: String, usedPercent: Double?, minutes: Int? = nil, resetsAt: Date? = nil,
    resetDescription: String? = nil, remainingTokens: Double? = nil
  ) {
    self.id = id
    self.title = title
    self.usedPercent = usedPercent
    self.minutes = minutes
    self.resetsAt = resetsAt
    self.resetDescription = resetDescription
    self.remainingTokens = remainingTokens
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
}
