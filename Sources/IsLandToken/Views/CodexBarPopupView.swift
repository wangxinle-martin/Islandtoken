import IslandCore
import SwiftUI

/// IsLandToken data/interaction adapter around CodexBar's original metric components.
struct CodexBarPopupView: View {
  @ObservedObject var store: AppStore
  @ObservedObject var state: IslandState
  private var providers: [Provider] {
    [store.preferences.left.provider, store.preferences.right.provider].reduce(into: []) {
      if !$0.contains($1) { $0.append($1) }
    }
  }
  var body: some View {
    VStack(spacing: 0) {
      TimelineView(.periodic(from: .now, by: 60)) { timeline in
        HStack(alignment: .top, spacing: 0) {
          ForEach(providers) { provider in
            card(provider: provider, now: timeline.date)
              .frame(maxWidth: .infinity, alignment: .topLeading)
          }
        }
      }
      Divider().padding(.horizontal, UsageMenuCardLayout.horizontalPadding)
      HStack(spacing: 12) {
        PopupAction(title: "控制台", symbol: "slider.horizontal.3") {
          AppDelegate.shared?.showDashboard()
        }
        PopupAction(title: "固定", symbol: state.pinned ? "pin.fill" : "pin") {
          state.pinned.toggle()
        }
        PopupAction(
          title: store.refreshing ? "刷新中" : "刷新", symbol: "arrow.clockwise",
          enabled: !store.refreshing && !store.demoMode
        ) {
          Task {
            await store.refresh()
            store.schedule()
            await store.refreshCosts()
          }
        }
        PopupAction(title: "关于", symbol: "info.circle") { NSApp.orderFrontStandardAboutPanel(nil) }
        PopupAction(title: "退出", symbol: "xmark.rectangle") { NSApp.terminate(nil) }
      }
      .padding(.horizontal, UsageMenuCardLayout.horizontalPadding).padding(.vertical, 10)

    }
    .frame(width: state.popupWidth(store.preferences))
    .fixedSize(horizontal: false, vertical: true)
    .background(.regularMaterial)
    .background(
      GeometryReader { geometry in
        Color.clear.preference(key: PopupHeightKey.self, value: geometry.size.height)
      }
    )
    .onPreferenceChange(PopupHeightKey.self) { height in
      guard height > 0, abs(state.popupHeight - height) > 0.5 else { return }
      state.popupHeight = height
    }
    .task { await store.refreshCosts() }
  }

  private func card(provider: Provider, now: Date) -> some View {
    let reading = store.readings[provider]
    return VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: UsageMenuCardLayout.headerContentSpacing) {
        UsageMenuCardHeaderView(
          model: .init(
            providerName: provider.name, email: reading?.accountEmail ?? "",
            subtitleText: store.demoMode
              ? "演示数据"
              : reading?.error ?? reading.map {
                String(max(0, Int(now.timeIntervalSince($0.updatedAt) / 60))) + "分钟前已更新"
              } ?? "等待额度数据",
            subtitleStyle: reading?.error == nil ? .info : .error, planText: reading?.plan))
        Divider()
      }.padding(.top, UsageMenuCardLayout.headerOnlyVerticalPadding)
        .padding(.bottom, UsageMenuCardLayout.sectionBottomPadding)
      VStack(alignment: .leading, spacing: 12) {
        ForEach(visibleWindows(reading)) { window in
          let metric = metric(window, provider: provider, now: now)
          MetricRow(
            metric: metric, layoutMetric: metric, title: metric.title,
            progressColor: store.demoTint
              ?? (provider == store.preferences.left.provider
              ? store.preferences.left.accent : store.preferences.right.accent).color(for: provider)
          )
        }
        if reading?.windows.isEmpty != false {
          Text("暂无额度数据").font(.subheadline).foregroundStyle(.secondary)
        }
        if let resetCredits = resetCredits(reading, now: now) {
          Divider()
          CodexResetCreditsContent(presentation: resetCredits)
        }
        if let credits = reading?.credits {
          Divider()
          Text("可用积分 \(credits.formatted())").font(.body.weight(.medium))
        }
        if !store.demoMode, let cost = store.costs[provider],
          cost.sessionTokens != nil || cost.sessionCostUSD != nil || cost.last30DaysTokens != nil
            || cost.last30DaysCostUSD != nil
        {
          Divider()
          TokenUsageSectionContent(
            provider: provider,
            tokenUsage: .init(
              isRefreshing: store.refreshingCost,
              sessionLine:
                "今日：\(cost.sessionTokens.map { $0.formatted() } ?? "—") Token · \(money(cost.sessionCostUSD))",
              monthLine:
                "30 天：\(cost.last30DaysTokens.map { $0.formatted() } ?? "—") Token · \(money(cost.last30DaysCostUSD))",
              hintLine: "按本机日志估算", errorLine: store.costErrors[provider], errorCopyText: nil),
            showsCodexHint: true, lineFont: .footnote)
        }
      }.padding(.top, UsageMenuCardLayout.usageSectionTopPadding)
        .padding(.bottom, UsageMenuCardLayout.sectionBottomPadding)
    }.padding(.horizontal, UsageMenuCardLayout.horizontalPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
  private func resetCredits(_ reading: UsageReading?, now: Date) -> CodexResetCreditsPresentation? {
    let credits = (reading?.resetCredits ?? []).filter { $0.expiresAt.map { $0 > now } ?? true }
      .sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
    guard !credits.isEmpty else { return nil }
    let formatter = DateFormatter()
    formatter.dateFormat = "MM月dd日 HH:mm"
    return .init(
      text: "\(credits.count) 次可用",
      items: credits.map {
        let text = $0.expiresAt.map { formatter.string(from: $0) } ?? "无到期时间"
        return .init(expiryText: text, compactExpiryText: text)
      })
  }
  private func money(_ amount: Double?) -> String {
    amount.map { String(format: "$%.2f", $0) } ?? "—"
  }
  private func visibleWindows(_ reading: UsageReading?) -> [QuotaWindow] {
    // Synthetic Antigravity aggregate lanes duplicate model rows and are headline-only.
    reading?.windows.filter { !$0.id.hasPrefix("antigravity-quota-summary-") } ?? []
  }
  private func pace(_ window: QuotaWindow, provider: Provider, now: Date) -> UsagePace? {
    guard !store.demoMode, store.readings[provider]?.error == nil, let rate = RateWindow(window),
      rate.remainingPercent > 0,
      [.codex, .claude, .antigravity].contains(provider)
    else { return nil }
    if window.minutes == 300 {
      return UsagePaceText.sessionPace(provider: provider, window: rate, now: now)
    }
    guard window.minutes == 10080,
      let pace = UsagePace.weekly(window: rate, now: now), pace.expectedUsedPercent >= 3
    else { return nil }
    return pace
  }
  private func metric(_ window: QuotaWindow, provider: Provider, now: Date)
    -> UsageMenuCardView.Model.Metric
  {
    let title: String
    if provider != .antigravity && window.id == "primary" && window.minutes == 300 {
      title = "会话"
    } else if provider != .antigravity && window.id == "secondary" && window.minutes == 10080 {
      title = "每周"
    } else {
      title = window.title
    }
    let pace = pace(window, provider: provider, now: now)
    let detail = pace.map { UsagePaceText.weeklyDetail(provider: provider, pace: $0, now: now) }
    return .init(
      id: window.id, title: title,
      percent: window.percent(remaining: store.preferences.remaining) ?? 0,
      percentStyle: store.preferences.remaining ? .left : .used,
      statusText: window.usedPercent == nil ? "暂无额度数据" : nil,
      resetText: ResetLabel(window: window, absolute: store.preferences.absoluteResetTime).text(
        now: now),
      detailText: nil, detailLeftText: detail?.leftLabel, detailRightText: detail?.rightLabel,
      pacePercent: pace.flatMap {
        $0.stage == .onTrack
          ? nil
          : (store.preferences.remaining ? 100 - $0.expectedUsedPercent : $0.expectedUsedPercent)
      },
      detailIsPaceDerived: pace != nil,
      paceOnTop: pace.map { $0.actualUsedPercent <= $0.expectedUsedPercent } ?? true,
      warningMarkerPercents: store.preferences.alerts
        ? [store.preferences.warningPercent, store.preferences.criticalPercent].map {
          store.preferences.remaining ? $0 : 100 - $0
        } : [])
  }
}

private struct PopupHeightKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

/// Native controls receive the first click in the nonactivating island panel.
private struct PopupAction: NSViewRepresentable {
  let title: String
  let symbol: String
  var enabled = true
  let action: () -> Void
  final class Coordinator: NSObject {
    var action: () -> Void
    init(action: @escaping () -> Void) { self.action = action }
    @objc func invoke(_ sender: NSButton) { action() }
  }
  final class Button: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
  }
  func makeCoordinator() -> Coordinator { Coordinator(action: action) }
  func makeNSView(context: Context) -> Button {
    let button = Button(
      title: title, target: context.coordinator, action: #selector(Coordinator.invoke(_:)))
    button.isBordered = false
    button.imagePosition = .imageLeading
    button.font = .systemFont(ofSize: 13)
    button.setContentHuggingPriority(.required, for: .horizontal)
    return button
  }
  func updateNSView(_ button: Button, context: Context) {
    context.coordinator.action = action
    button.title = title
    button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
    button.isEnabled = enabled
  }
  func sizeThatFits(_ proposal: ProposedViewSize, nsView: Button, context: Context) -> CGSize? {
    nsView.intrinsicContentSize
  }
}
