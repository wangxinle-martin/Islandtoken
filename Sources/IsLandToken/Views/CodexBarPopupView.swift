import IslandCore
import SwiftUI

/// IsLandToken data/interaction adapter around CodexBar's original metric components.
struct CodexBarPopupView: View {
  @ObservedObject var store: AppStore
  @ObservedObject var state: IslandState
  @AppStorage("interfaceLanguage") private var interfaceLanguage = InterfaceLanguage.chinese.rawValue
  @State private var stablePopupHeight: CGFloat?
  private var providers: [Provider] {
    [store.preferences.left.provider, store.preferences.right.provider].reduce(into: []) {
      if !$0.contains($1) { $0.append($1) }
    }
  }
  private var maximumMiddleHeight: CGFloat {
    max(
      120,
      state.screenHeight - state.headlineHeight - UsageMenuCardLayout.actionAreaReservedHeight)
  }
  var body: some View {
    VStack(spacing: 0) {
      ScrollView(.vertical) {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
          HStack(alignment: .top, spacing: 0) {
            ForEach(providers) { provider in
              card(provider: provider, now: timeline.date)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
          }
          // Keep 20pt outer margins while tightening the gutter between two
          // provider cards (12.5 + 7.5 = 20pt outer / 7.5 + 7.5 = 15pt middle).
          .padding(.horizontal, UsageMenuCardLayout.popupOuterHorizontalInset)
        }
      }
      .scrollBounceBehavior(.basedOnSize)
      .frame(width: state.width(store.preferences))
      .frame(maxHeight: maximumMiddleHeight)
      .fixedSize(horizontal: false, vertical: true)
      Divider().padding(.horizontal, UsageMenuCardLayout.horizontalPadding)
      HStack(spacing: 12) {
        PopupAction(title: T("设置"), symbol: "gearshape", emphasized: store.dashboardOpen) {
          AppDelegate.shared?.showDashboard()
        }
        PopupAction(title: T("固定"), symbol: state.pinned ? "pin.fill" : "pin") {
          state.pinned.toggle()
        }
        PopupAction(
          title: T("刷新"), symbol: "arrow.clockwise",
          enabled: !store.refreshing && !store.refreshingCost && !store.demoMode,
          active: store.refreshing || store.refreshingCost,
          rotating: store.refreshing || store.refreshingCost
        ) {
          Task {
            await store.refresh()
            store.schedule()
            await store.refreshCosts()
          }
        }
        PopupAction(title: T("关于"), symbol: "info.circle") { NSApp.orderFrontStandardAboutPanel(nil) }
        PopupAction(title: T("退出"), symbol: "xmark.rectangle") { NSApp.terminate(nil) }
      }
      .padding(.horizontal, UsageMenuCardLayout.horizontalPadding)
      .frame(height: UsageMenuCardLayout.actionAreaContentHeight)
      // Center native AppKit controls in the entire reserved footer, including
      // the lower-corner clearance, so they never appear to jump upward.
      .frame(height: UsageMenuCardLayout.actionAreaReservedHeight)
    }
    .fixedSize(horizontal: true, vertical: true)
    .background(.regularMaterial)
    .onGeometryChange(for: CGSize.self) { geometry in
      geometry.size
    } action: { size in
      let height = ceil(size.height)
      guard stablePopupHeight == nil, height > 0 else { return }
      stablePopupHeight = height
      if abs(state.popupHeight - height) > 0.5 {
        state.popupHeight = height
      }
    }
    .id(interfaceLanguage)
  }

  private func card(provider: Provider, now: Date) -> some View {
    let reading = store.readings[provider]
    return VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: UsageMenuCardLayout.headerContentSpacing) {
        UsageMenuCardHeaderView(
          model: .init(
            providerName: provider.name, email: reading?.accountEmail ?? "",
            subtitleText: store.demoMode
              ? T("演示模式")
              : reading?.error.map { T($0) } ?? reading.map {
                T("%d分钟前已更新", max(0, Int(now.timeIntervalSince($0.updatedAt) / 60)))
              } ?? T("等待额度数据"),
            subtitleStyle: reading?.error == nil ? .info : .error, planText: reading?.plan))
        Divider()
      }.padding(.top, UsageMenuCardLayout.headerOnlyVerticalPadding)
        .padding(.bottom, UsageMenuCardLayout.sectionBottomPadding)
      VStack(alignment: .leading, spacing: 12) {
        PopupOverviewSection(
          reading: reading, stale: reading?.stale(refreshMinutes: store.effectiveRefreshMinutes) ?? true,
          refreshDescription: store.refreshDescription)
        ForEach(visibleWindows(reading)) { window in
          let metric = metric(window, provider: provider, now: now)
          MetricRow(
            metric: metric, layoutMetric: metric, title: metric.title,
            progressColor: store.demoTint
              ?? (provider == store.preferences.left.provider
              ? store.preferences.left.accent : store.preferences.right.accent).color(
                for: provider, preferences: store.preferences)
          )
        }
        PopupRecentSamplesSection(
          samples: recentSamples(provider: provider),
          windowTitles: sampleWindowTitles(reading),
          remaining: store.preferences.remaining)
        if reading?.windows.isEmpty != false {
          Text(T("暂无额度数据")).font(.subheadline).foregroundStyle(.secondary)
        }
        if let resetCredits = resetCredits(reading, now: now) {
          Divider()
          CodexResetCreditsContent(presentation: resetCredits)
        }
        if let credits = reading?.credits {
          Divider()
          Text(T("可用积分 %@", credits.formatted())).font(.body.weight(.medium))
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
                T("今日：%@ Token · %@", cost.sessionTokens.map { $0.formatted() } ?? "—", money(cost.sessionCostUSD)),
              monthLine:
                T("30 天：%@ Token · %@", cost.last30DaysTokens.map { $0.formatted() } ?? "—", money(cost.last30DaysCostUSD)),
              hintLine: T("按本机日志估算"), errorLine: store.costErrors[provider], errorCopyText: nil),
            showsCodexHint: true, lineFont: .footnote)
        } else if !store.demoMode {
          PopupUnavailableCostSection()
        }
      }.padding(.top, UsageMenuCardLayout.usageSectionTopPadding)
        .padding(.bottom, UsageMenuCardLayout.sectionBottomPadding)
    }.padding(.horizontal, UsageMenuCardLayout.cardHorizontalPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
  private func resetCredits(_ reading: UsageReading?, now: Date) -> CodexResetCreditsPresentation? {
    let credits = (reading?.resetCredits ?? []).filter { $0.expiresAt.map { $0 > now } ?? true }
      .sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
    guard !credits.isEmpty else { return nil }
    let formatter = DateFormatter()
    formatter.locale = UserDefaults.standard.string(forKey: "interfaceLanguage") == InterfaceLanguage.english.rawValue
      ? Locale(identifier: "en_US") : Locale(identifier: "zh_CN")
    formatter.dateFormat = UserDefaults.standard.string(forKey: "interfaceLanguage") == InterfaceLanguage.english.rawValue
      ? "MMM d, HH:mm" : "MM月dd日 HH:mm"
    return .init(
      text: T("%d 次可用", credits.count),
      items: credits.map {
        let text = $0.expiresAt.map { formatter.string(from: $0) } ?? T("无到期时间")
        return .init(expiryText: text, compactExpiryText: text)
      })
  }
  private func money(_ amount: Double?) -> String {
    amount.map { String(format: "$%.2f", $0) } ?? "—"
  }
  private func recentSamples(provider: Provider) -> [Sample] {
    Array(store.samples.lazy.filter { $0.provider == provider }.suffix(3).reversed())
  }
  private func sampleWindowTitles(_ reading: UsageReading?) -> [String: String] {
    Dictionary(uniqueKeysWithValues: (reading?.windows ?? []).map { ($0.id, $0.title) })
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
  private func regenerationDetail(_ window: QuotaWindow) -> String? {
    guard let regen = window.nextRegenPercent, regen.isFinite, regen > 0,
      window.resetsAt != nil, let remaining = window.remainingPercent
    else { return nil }
    let recovered = min(100, remaining + regen)
    let value = store.preferences.remaining ? recovered : 100 - recovered
    return T("下次恢复后 %.0f%% %@", value, T(store.preferences.remaining ? "剩余" : "已用"))
  }

  private func metric(_ window: QuotaWindow, provider: Provider, now: Date)
    -> UsageMenuCardView.Model.Metric
  {
    let title: String
    if provider != .antigravity && window.id == "primary" && window.minutes == 300 {
      title = T("会话")
    } else if provider != .antigravity && window.id == "secondary" && window.minutes == 10080 {
      title = T("每周")
    } else {
      title = window.title
    }
    let pace = pace(window, provider: provider, now: now)
    let detail = pace.map { UsagePaceText.weeklyDetail(provider: provider, pace: $0, now: now) }
    return .init(
      id: window.id, title: title,
      percent: window.percent(remaining: store.preferences.remaining) ?? 0,
      percentStyle: store.preferences.remaining ? .left : .used,
      statusText: window.usedPercent == nil ? T("暂无额度数据") : nil,
      resetText: ResetLabel(window: window, absolute: store.preferences.absoluteResetTime).text(
        now: now),
      detailText: regenerationDetail(window), detailLeftText: detail?.leftLabel,
      detailRightText: detail?.rightLabel,
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

private struct PopupOverviewSection: View {
  let reading: UsageReading?
  let stale: Bool
  let refreshDescription: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label(T("额度概览"), systemImage: "chart.bar.xaxis")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Text(stale ? T("数据待更新") : T("实时数据"))
          .font(.caption.weight(.medium))
          .foregroundStyle(stale ? .orange : .secondary)
      }
      HStack(spacing: 0) {
        summary(T("采集"), sourceLabel(reading?.source))
        Divider().frame(height: 28).padding(.horizontal, 12)
        summary(T("刷新"), refreshDescription)
      }
    }
    .padding(10)
    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
  }

  private func summary(_ title: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title).font(.caption2).foregroundStyle(.secondary)
      Text(value).font(.caption.weight(.medium)).lineLimit(1).truncationMode(.tail)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func sourceLabel(_ source: String?) -> String {
    guard let source, !source.isEmpty else { return T("等待连接") }
    // The parser preserves provenance details (for example, "CodexBar · app").
    // The detailed suffix is useful for diagnostics but makes this compact card noisy.
    return source.components(separatedBy: " · ").first ?? source
  }
}

private struct PopupRecentSamplesSection: View {
  let samples: [Sample]
  let windowTitles: [String: String]
  let remaining: Bool

  var body: some View {
    guard !samples.isEmpty else { return AnyView(EmptyView()) }
    return AnyView(
      VStack(alignment: .leading, spacing: 6) {
        Divider()
        Label(T("最近本地采样"), systemImage: "clock.arrow.circlepath")
          .font(.subheadline.weight(.semibold))
        ForEach(samples) { sample in
          HStack {
            Text(label(for: sample))
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.tail)
            Spacer(minLength: 12)
            Text(sample.date.formatted(date: .omitted, time: .shortened))
              .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
              .frame(width: 38, alignment: .trailing)
            Text(String(format: "%.0f%%", remaining ? 100 - sample.used : sample.used))
              .font(.caption.weight(.semibold)).monospacedDigit()
              .frame(width: 38, alignment: .trailing)
          }
        }
      })
  }

  private func label(for sample: Sample) -> String {
    if let title = windowTitles[sample.windowID], !title.isEmpty { return title }
    let prefix = "antigravity-quota-summary-"
    if sample.windowID.hasPrefix(prefix) {
      return sample.windowID
        .dropFirst(prefix.count)
        .replacingOccurrences(of: "-", with: " · ")
    }
    return sample.windowID.replacingOccurrences(of: "-", with: " · ")
  }
}

private struct PopupUnavailableCostSection: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Divider()
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Label(T("Token 与费用"), systemImage: "chart.line.uptrend.xyaxis")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Text(T("当前来源暂无记录"))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}

/// Native controls receive the first click in the nonactivating island panel.
private struct PopupAction: NSViewRepresentable {
  let title: String
  let symbol: String
  var enabled = true
  var active = false
  var rotating = false
  var emphasized = false
  let action: () -> Void
  final class Coordinator: NSObject {
    var action: () -> Void
    init(action: @escaping () -> Void) { self.action = action }
    @objc func invoke(_ sender: NSButton) { action() }
  }
  final class RotatingCell: NSButtonCell {
    var angle: CGFloat = 0
    override func drawImage(_ image: NSImage, withFrame frame: NSRect, in controlView: NSView) {
      NSGraphicsContext.saveGraphicsState()
      if let context = NSGraphicsContext.current?.cgContext {
        context.translateBy(x: frame.midX, y: frame.midY)
        context.rotate(by: angle)
        context.translateBy(x: -frame.midX, y: -frame.midY)
      }
      super.drawImage(image, withFrame: frame, in: controlView)
      NSGraphicsContext.restoreGraphicsState()
    }
  }
  final class Button: NSButton {
    private var rotationTimer: Timer?
    func setRotating(_ rotating: Bool) {
      let animate = rotating && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
      guard animate != (rotationTimer != nil) else { return }
      rotationTimer?.invalidate()
      rotationTimer = nil
      (cell as? RotatingCell)?.angle = 0
      if animate {
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
          MainActor.assumeIsolated {
            guard let self else { return }
            (self.cell as? RotatingCell)?.angle += .pi * 2 / 30
            self.needsDisplay = true
          }
        }
        rotationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
      }
      needsDisplay = true
    }
    deinit { rotationTimer?.invalidate() }

    var active = false
    override func highlight(_ flag: Bool) {
      super.highlight(flag)
      updateTint(pressed: flag)
    }
    func updateTint(pressed: Bool? = nil) {
      let color: NSColor = active || (pressed ?? isHighlighted) ? .white : .labelColor
      contentTintColor = color
      attributedTitle = NSAttributedString(
        string: title,
        attributes: [
          .foregroundColor: color, .font: font ?? NSFont.systemFont(ofSize: 13),
        ])
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
  }
  func makeCoordinator() -> Coordinator { Coordinator(action: action) }
  func makeNSView(context: Context) -> Button {
    let button = Button(
      title: title, target: context.coordinator, action: #selector(Coordinator.invoke(_:)))
    button.cell = RotatingCell(textCell: title)
    button.target = context.coordinator
    button.action = #selector(Coordinator.invoke(_:))
    button.isBordered = false
    button.imagePosition = .imageLeading
    button.font = .systemFont(ofSize: 13)
    button.setContentHuggingPriority(.required, for: .horizontal)
    return button
  }
  func updateNSView(_ button: Button, context: Context) {
    context.coordinator.action = action
    button.title = title
    button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
      .withSymbolConfiguration(.init(pointSize: 13, weight: emphasized ? .bold : .regular))
    button.setRotating(rotating)
    button.isEnabled = enabled
    button.active = active
    button.updateTint()
  }
  func sizeThatFits(_ proposal: ProposedViewSize, nsView: Button, context: Context) -> CGSize? {
    nsView.intrinsicContentSize
  }
}
