import IslandCore
import SwiftUI

struct IslandView: View {
  @ObservedObject var store: AppStore
  @ObservedObject var state: IslandState
  @AppStorage("interfaceLanguage") private var interfaceLanguage = InterfaceLanguage.chinese.rawValue
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var displayedShellWidth: CGFloat?
  @State private var displayedShellOffsetX: CGFloat?
  @State private var displayedShellExpansion: CGFloat?

  var body: some View {
    let layout = state.headlineLayout(store.preferences)
    VStack(spacing: 0) {
      VStack(spacing: 0) {
        Button {
          AppDelegate.shared?.island?.showDetailsFromHeadline()
        } label: {
          HStack(spacing: 0) {
            if layout.placement == .left { sparkleSlot }
            IslandHeadlines(
              store: store, revealed: state.displaysRevealedHeadline, items: layout.leading,
              outerEdge: .leading, expansion: state.leftHeaderExpansion(store.preferences))
            Color.clear.frame(width: state.notchWidth)
              .overlay(alignment: .bottom) {
                if store.demoMode {
                  Text(T("示例")).font(.system(size: 7, weight: .bold)).foregroundStyle(.orange)
                    .padding(.bottom, 2)
                }
              }
            IslandHeadlines(
              store: store, revealed: state.displaysRevealedHeadline, items: layout.trailing,
              outerEdge: .trailing, expansion: state.rightHeaderExpansion(store.preferences))
            if layout.placement != .left { sparkleSlot }
          }
          .fixedSize(horizontal: true, vertical: false)
          .offset(x: shellTarget.offsetX - shellLayout.offsetX)
          .animation(
            reduceMotion ? nil
              : (shellTarget.width < shellLayout.width
                ? IslandState.shellCollapseMotion : shellMotion),
            value: shellTarget)
          .frame(width: shellLayout.width, height: state.headlineHeight)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
          Button(T("打开设置")) { AppDelegate.shared?.showDashboard() }
          Button(T("立即刷新")) {
            Task {
              await store.refresh()
              store.schedule()
            }
          }.keyboardShortcut("r", modifiers: .command)
          Button(T("左右互换")) {
            store.preferences.swapIslandSides()
          }
          Divider()
          Button(T("退出 IsLandToken")) { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
          T(
            store.preferences.detailInteraction == .none
              ? "IsLandToken 额度" : state.expanded ? "IsLandToken 详情已显示" : "显示 IsLandToken 详情")
        )
        // Retain the hardware-like black headline while the detail body below
        // refracts the desktop through the system material.
        .background(Color.black)
        // Keep the complete detail body mounted at its final layout size.
        // Only the viewport height changes, so the visible edge travels from
        // the header downward instead of scaling the cards and text.
        popupViewport
      }
      // 展开时根据内容自动宽度，收起时使用紧凑宽度
      .frame(width: shellLayout.width, alignment: .top)
      // The detail body refracts the desktop through the system material.
      // The headline above paints black over this material, preserving the
      // hardware-like compact Island when no detail is shown.
      .background(.ultraThinMaterial)
      .clipShape(islandShape)
      .overlay {
        IslandLowerEdge(
          expansionProgress: shellLayout.expansion,
          notchAttachment: notchAttachment)
          .stroke(Color.white.opacity(0.24), lineWidth: 1)
          .opacity(state.popupRevealed ? 1 : 0)
          .animation(popupRevealMotion, value: state.popupRevealed)
          .allowsHitTesting(false)
        if store.refreshAnimationActive {
          if [.radar, .pixels, .waves, .rain].contains(
            store.effectiveRefreshAnimation)
          {
            IslandRefreshEffects(style: store.effectiveRefreshAnimation)
              .id(store.animationPreviewID)
              .clipShape(islandShape)
          }
          if store.effectiveRefreshAnimation == .meteor {
            IslandRefreshMeteor(expanded: state.shellExpanded).id(store.animationPreviewID)
              .clipShape(islandShape)
          }
          if store.effectiveRefreshAnimation == .glow {
            IslandRefreshGlowBorder(
              expanded: state.shellExpanded, notchAttachment: notchAttachment)
          }
        }
      }
      .shadow(color: .black.opacity(state.popupRevealed ? 0.35 : 0), radius: 14, y: 8)
      .animation(popupRevealMotion, value: state.popupRevealed)
      Spacer(minLength: 0)
    }
    .offset(x: shellLayout.offsetX)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .preferredColorScheme(.dark)
    // The shell owns only horizontal size and placement. The popup below has
    // its own height-only animation, preventing a root layout transaction
    // from making the detail content look as though it is being scaled.
    .onAppear { updateShellLayout(shellTarget, animated: false) }
    .onChange(of: shellTarget) { _, layout in updateShellLayout(layout, animated: true) }
    .id(interfaceLanguage)

  }
  private var shellTarget: IslandShellLayout {
    IslandShellLayout(
      width: state.width(store.preferences),
      offsetX: state.contentOffsetX(store.preferences),
      expansion: state.shellExpanded ? 1 : 0)
  }

  private var shellLayout: IslandShellLayout {
    IslandShellLayout(
      width: displayedShellWidth ?? shellTarget.width,
      offsetX: displayedShellOffsetX ?? shellTarget.offsetX,
      expansion: displayedShellExpansion ?? shellTarget.expansion)
  }

  private func updateShellLayout(_ layout: IslandShellLayout, animated: Bool) {
    let apply = {
      displayedShellWidth = layout.width
      displayedShellOffsetX = layout.offsetX
      displayedShellExpansion = layout.expansion
    }
    guard animated, !reduceMotion else {
      var transaction = Transaction()
      transaction.animation = nil
      withTransaction(transaction) { apply() }
      return
    }
    let isShrinking = displayedShellWidth.map { layout.width < $0 } ?? false
    withAnimation(isShrinking ? IslandState.shellCollapseMotion : shellMotion) { apply() }
  }

  private var shellMotion: Animation {
    .smooth(duration: IslandState.shellAnimationDuration, extraBounce: 0)
  }

  private var popupMotion: Animation {
    .smooth(duration: IslandState.popupRevealDuration, extraBounce: 0)
  }

  // Reveal keeps the quick popup curve; retract matches the shell collapse so
  // height, width and headline contract together on one continuous motion.
  private var popupRevealMotion: Animation? {
    reduceMotion ? nil : (state.popupRevealed ? popupMotion : IslandState.shellCollapseMotion)
  }

  private var sparkleSlot: some View {
    Color.clear
      .frame(width: state.sparkleWidth(store.preferences), height: state.headlineHeight)
      .overlay {
        if store.effectiveRefreshAnimation == .sparkle, store.refreshAnimationActive {
          IslandRefreshSparkle().frame(width: 8, height: 12)
            .offset(x: store.preferences.islandHeadlinePlacement == .left ? 7 : -7)
        }
      }
      .allowsHitTesting(false)
  }

  private var popupViewport: some View {
    let contentWidth = state.expandedIslandWidth(store.preferences)
    let visibleHeight = state.popupRevealed ? state.popupHeight : 0
    return Color.clear
      // The clear viewport is the only vertically changing element. Its
      // overlay remains at full intrinsic size and is merely clipped below the
      // moving lower edge.
      .frame(width: contentWidth, height: visibleHeight, alignment: .top)
      .overlay(alignment: .top) {
        CodexBarPopupView(store: store, state: state)
          .frame(width: contentWidth, alignment: .top)
          .fixedSize(horizontal: false, vertical: true)
          // Do not inherit the shell's width/shape animation: the body must
          // retain its final typography and card layout while being revealed.
          .transaction { $0.animation = nil }
      }
      .clipped()
      .allowsHitTesting(state.popupRevealed)
      .accessibilityHidden(!state.popupRevealed)
      .animation(popupRevealMotion, value: state.popupRevealed)
  }

  private var notchAttachment: IslandNotchAttachment {
    IslandNotchAttachment(store.preferences.islandHeadlinePlacement)
  }

  private var islandShape: IslandShape {
    IslandShape(expansionProgress: shellLayout.expansion, notchAttachment: notchAttachment)
  }

}

private struct IslandShellLayout: Equatable {
  var width: CGFloat
  var offsetX: CGFloat
  var expansion: CGFloat
}

struct IslandHeadlines: View {
  @ObservedObject var store: AppStore
  var revealed: Bool
  var items: ArraySlice<IslandHeadlineLayout.Item>
  var outerEdge: HorizontalEdge
  var expansion: CGFloat = 0

  var body: some View {
    HStack(spacing: IslandHeadlineLayout.spacing) {
      ForEach(items.indices, id: \.self) { index in
        let item = items[index]
        SideHeadline(
          store: store, configuration: item.configuration, revealed: revealed,
          leadingInset: item.leadingInset, trailingInset: item.trailingInset,
          revealedLeadingContentInset: item.revealedLeadingInset,
          revealedTrailingContentInset: item.revealedTrailingInset,
          revealedAnchor: outerEdge == .trailing && index == items.endIndex - 1
            ? .trailing : .leading)
          .frame(
            width: item.width + (items.count == 1 ? expansion : 0),
            alignment: alignment)
          .clipped()
      }
    }
    .fixedSize(horizontal: true, vertical: false)
    .padding(outerEdge == .leading ? .trailing : .leading, items.count > 1 ? expansion : 0)
  }

  private var alignment: Alignment { outerEdge == .leading ? .leading : .trailing }
}

struct SideHeadline: View {
  @ObservedObject var store: AppStore
  var configuration: SideConfiguration
  var revealed = false
  var leadingInset: CGFloat = 0
  var trailingInset: CGFloat = 0
  var revealedLeadingContentInset: CGFloat = 0
  var revealedTrailingContentInset: CGFloat = 0
  var revealedAnchor: UnitPoint = .center
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    let reading = store.readings[configuration.provider]
    let stale = reading?.stale(refreshMinutes: store.effectiveRefreshMinutes) ?? true
    let displayWindowIDs = configuration.displayWindowIDs(reading: reading)
    // One container in both states: swapping ScrollView for a fixed-size view
    // on collapse would pop the content while the shell width animates.
    ScrollView(.horizontal) {
      headlineContent(reading: reading, stale: stale, windowIDs: displayWindowIDs)
        .padding(.leading, revealedLeadingContentInset)
        .padding(.trailing, revealedTrailingContentInset)
    }
    .scrollIndicators(.hidden)
    .defaultScrollAnchor(revealedAnchor)
    // Insets stay outside the content so width measurement and rendering agree.
    .padding(.leading, leadingInset)
    .padding(.trailing, trailingInset)
    .frame(height: 20)
    .help(
      "\(configuration.provider.name) · "
        + displayWindowIDs.map {
          (reading?.window($0)).map { UserFacingText.quotaTitle($0.title) } ?? $0
        }.joined(separator: " / ") + (stale ? " · \(T("数据待更新"))" : ""))
  }
  private func headlineContent(
    reading: UsageReading?, stale: Bool, windowIDs: [String]
  ) -> some View {
    HStack(spacing: 4) {
      if revealed && configuration.showIcon {
        ProviderIcon(provider: configuration.provider, size: 13, color: tint(nil))
          .transition(.opacity)
      }
      if revealed && configuration.showName {
        Text(configuration.provider == .antigravity ? "Anti" : configuration.provider.name)
          .font(.system(size: 9)).lineLimit(1)
          .transition(.opacity)
      }
      ForEach(Array(windowIDs.enumerated()), id: \.element) { index, id in
        if index > 0 {
          Text("|").font(.system(size: 12, weight: .semibold)).foregroundStyle(tint(nil))
        }
        quota(reading?.window(id), id: id)
          .help(
            (reading?.window(id)).map { UserFacingText.quotaTitle($0.title) }
              ?? T("%@ · 暂无额度", id))
      }
      if revealed && stale && !store.demoMode {
        Circle().fill(.orange).frame(width: 3, height: 3)
          .transition(.opacity)
      }
    }
    .fixedSize(horizontal: true, vertical: false)
    .opacity(stale && !store.demoMode ? 0.65 : 1)
  }
  private func quota(_ window: QuotaWindow?, id: String) -> some View {
    let remaining = store.preferences.remaining
    let percent = window?.percent(remaining: remaining)
    let styles = configuration.displayStyles(revealed: revealed, hasQuota: percent != nil)
    return HStack(alignment: .center, spacing: 4) {
      ForEach(styles) { style in
        if style == .number {
          DigitFlipText(
            text: percent.map { String(format: "%.0f", $0) + (revealed ? "%" : "") } ?? "—",
            active: store.effectiveRefreshAnimation == .digitFlip && store.refreshAnimationActive,
            color: tint(window))
        } else {
          QuotaGauge(
            value: percent, style: style, color: tint(nil),
            samples: style == .sparkline
              ? store.history(provider: configuration.provider, windowID: id) : [],
            remaining: remaining, compact: true)
        }
      }
    }
  }
  private func tint(_ window: QuotaWindow?) -> Color {
    if let demoTint = store.demoTint { return demoTint }
    if store.preferences.alerts, let value = window?.remainingPercent {
      if value <= store.preferences.criticalPercent { return .red }
      if value <= store.preferences.warningPercent { return .orange }
    }
    // The island always follows the selected provider's emphasis color.
    return store.preferences.providerColor(configuration.provider)
  }
}
