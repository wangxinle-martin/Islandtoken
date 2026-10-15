import IslandCore
import SwiftUI

struct IslandView: View {
  @ObservedObject var store: AppStore
  @ObservedObject var state: IslandState
  @AppStorage("interfaceLanguage") private var interfaceLanguage = InterfaceLanguage.chinese.rawValue
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 0) {
        Button {
          guard store.preferences.detailInteraction == .click else { return }
          state.showDetailsFromHeadline()
          if store.dashboardOpen { AppDelegate.shared?.focusDashboard() }
        } label: {
          HStack(spacing: 0) {
            if store.preferences.islandSideVisibility == .left { sparkleSlot }
            if store.preferences.islandSideVisibility != .right {
              Group {
                if store.preferences.islandSideVisibility == .left {
                  let widths = state.pairedSideWidths(store.preferences)
                  PairedHeadlines(
                    store: store, revealed: state.displaysRevealedHeadline,
                    leftWidth: widths.left, rightWidth: widths.right, outerEdge: .leading,
                    outerInset: headlineInsets.leading)
                } else {
                  SideHeadline(
                    store: store, configuration: store.preferences.left,
                    revealed: state.displaysRevealedHeadline,
                    leadingInset: headlineInsets.leading,
                    revealedLeadingContentInset: CGFloat(
                      IslandHeadlineInsets.revealedLeadingContentSafety),
                    revealedAnchor: .leading)
                }
              }.frame(
                width: state.leftWidth(store.preferences)
                  + state.leftHeaderExpansion(store.preferences)
                  - (store.preferences.islandSideVisibility == .left
                    ? state.sparkleWidth(store.preferences) : 0),
                alignment: .leading
              )
            }
            Color.clear.frame(width: state.notchWidth)
              .overlay(alignment: .bottom) {
                if store.demoMode {
                  Text("DEMO").font(.system(size: 7, weight: .bold)).foregroundStyle(.orange)
                    .padding(.bottom, 2)
                }
              }
            if store.preferences.islandSideVisibility != .left {
              Group {
                if store.preferences.islandSideVisibility == .right {
                  let widths = state.pairedSideWidths(store.preferences)
                  PairedHeadlines(
                    store: store, revealed: state.displaysRevealedHeadline,
                    leftWidth: widths.left, rightWidth: widths.right, outerEdge: .trailing,
                    outerInset: headlineInsets.trailing)
                } else {
                  SideHeadline(
                    store: store, configuration: store.preferences.right,
                    revealed: state.displaysRevealedHeadline,
                    trailingInset: headlineInsets.trailing,
                    revealedTrailingContentInset: CGFloat(
                      IslandHeadlineInsets.revealedLeadingContentSafety),
                    revealedAnchor: .trailing)
                }
              }.frame(
                width: state.rightWidth(store.preferences)
                  + state.rightHeaderExpansion(store.preferences)
                  - state.sparkleWidth(store.preferences),
                alignment: .trailing
              )
            }
            if store.preferences.islandSideVisibility != .left { sparkleSlot }
          }
          .frame(height: state.headlineHeight)
          .id("\(store.preferences.left.style.rawValue)-\(store.preferences.right.style.rawValue)")
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
            let left = store.preferences.left
            store.preferences.left = store.preferences.right
            store.preferences.right = left
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
        if state.expanded {
          expanded
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
      // 展开时根据内容自动宽度，收起时使用紧凑宽度
      .frame(
        width: state.width(store.preferences),
        alignment: .top
      )
      .background(Color.black)
      .clipShape(IslandShape(expanded: state.expanded))
      .overlay {
        if state.expanded {
          IslandLowerEdge(expanded: true)
            .stroke(Color.white.opacity(0.12), lineWidth: 1)
            .allowsHitTesting(false)
        }
        if store.refreshAnimationActive {
          if [.radar, .pixels, .waves, .rain].contains(
            store.effectiveRefreshAnimation)
          {
            IslandRefreshEffects(style: store.effectiveRefreshAnimation)
              .id(store.animationPreviewID)
              .clipShape(IslandShape(expanded: state.expanded))
          }
          if store.effectiveRefreshAnimation == .meteor {
            IslandRefreshMeteor(expanded: state.expanded).id(store.animationPreviewID)
              .clipShape(IslandShape(expanded: state.expanded))
          }
          if store.effectiveRefreshAnimation == .glow {
            IslandRefreshGlowBorder(expanded: state.expanded)
          }
        }
      }
      .shadow(color: .black.opacity(state.expanded ? 0.35 : 0), radius: 14, y: 8)
      Spacer(minLength: 0)
    }
    .offset(x: state.horizontalOffset(store.preferences))
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .preferredColorScheme(.dark)
    .animation(
      reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.62), value: state.expanded
    )
    .animation(
      reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.62),
      value: state.headlineRevealed)
    .id(interfaceLanguage)

  }
  private var sparkleSlot: some View {
    Color.clear
      .frame(width: state.sparkleWidth(store.preferences), height: state.headlineHeight)
      .overlay {
        if store.effectiveRefreshAnimation == .sparkle, store.refreshAnimationActive {
          IslandRefreshSparkle().frame(width: 8, height: 12)
            .offset(x: store.preferences.islandSideVisibility == .left ? 7 : -7)
        }
      }
      .allowsHitTesting(false)
  }

  private var headlineInsets: (leading: CGFloat, trailing: CGFloat) {
    let insets = IslandHeadlineInsets.resolve(
      for: store.preferences.islandSideVisibility,
      isMinimum: !state.displaysRevealedHeadline)
    return (CGFloat(insets.leading), CGFloat(insets.trailing))
  }

  private var expanded: some View {
    CodexBarPopupView(store: store, state: state)
  }

}

struct PairedHeadlines: View {
  @ObservedObject var store: AppStore
  var revealed: Bool
  var leftWidth: CGFloat
  var rightWidth: CGFloat
  var outerEdge: HorizontalEdge
  var outerInset: CGFloat
  var body: some View {
    HStack(spacing: IslandState.pairedHeadlineSpacing) {
      SideHeadline(
        store: store, configuration: store.preferences.left, revealed: revealed,
        leadingInset: outerEdge == .leading ? outerInset : 0,
        trailingInset: 0,
        revealedLeadingContentInset: outerEdge == .leading
          ? CGFloat(IslandHeadlineInsets.revealedLeadingContentSafety) : 0,
        revealedAnchor: .leading
      )
      .frame(width: leftWidth, alignment: outerEdge == .leading ? .leading : .trailing)
      SideHeadline(
        store: store, configuration: store.preferences.right, revealed: revealed,
        leadingInset: 0,
        trailingInset: outerEdge == .trailing ? outerInset : 0,
        revealedTrailingContentInset: outerEdge == .trailing
          ? CGFloat(IslandHeadlineInsets.revealedLeadingContentSafety) : 0,
        revealedAnchor: outerEdge == .trailing ? .trailing : .leading
      )
      .frame(width: rightWidth, alignment: outerEdge == .trailing ? .trailing : .leading)
    }
    .fixedSize(horizontal: true, vertical: false)
  }
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
    Group {
      if revealed {
        ScrollView(.horizontal) {
          headlineContent(reading: reading, stale: stale, windowIDs: displayWindowIDs)
            .padding(.leading, revealedLeadingContentInset)
            .padding(.trailing, revealedTrailingContentInset)
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(revealedAnchor)
      } else {
        // In the minimum state, use the selected quotas' intrinsic width.
        // A ScrollView has a flexible viewport and can compress the first
        // value into the island corner before the outer frame catches up.
        headlineContent(reading: reading, stale: stale, windowIDs: displayWindowIDs)
          .fixedSize(horizontal: true, vertical: false)
      }
    }
    // Insets stay outside the content so width measurement and rendering agree.
    .padding(.leading, leadingInset)
    .padding(.trailing, trailingInset)
    .frame(height: 20)
    .help(
      "\(configuration.provider.name) · "
        + displayWindowIDs.map {
          T(reading?.window($0)?.title ?? $0)
        }.joined(separator: " / ") + (stale ? " · \(T("数据待更新"))" : ""))
  }
  private func headlineContent(
    reading: UsageReading?, stale: Bool, windowIDs: [String]
  ) -> some View {
    HStack(spacing: 4) {
      if revealed && configuration.showIcon {
        ProviderIcon(provider: configuration.provider, size: 13, color: tint(nil))
      }
      if revealed && configuration.showName {
        Text(configuration.provider == .antigravity ? "Anti" : configuration.provider.name)
          .font(.system(size: 9)).lineLimit(1)
      }
      ForEach(Array(windowIDs.enumerated()), id: \.element) { index, id in
        if index > 0 {
          Text("|").font(.system(size: 12, weight: .semibold)).foregroundStyle(tint(nil))
        }
        quota(reading?.window(id), id: id)
          .help(T(reading?.window(id)?.title ?? "\(id) · 暂无额度"))
      }
      if revealed && stale && !store.demoMode {
        Circle().fill(.orange).frame(width: 3, height: 3)
      }
    }
    .fixedSize(horizontal: true, vertical: false)
    .opacity(stale && !store.demoMode ? 0.65 : 1)
  }
  private func quota(_ window: QuotaWindow?, id: String) -> some View {
    HStack(alignment: .center, spacing: 4) {
      if configuration.style != .number {
        QuotaGauge(
          value: window?.percent(remaining: store.preferences.remaining),
          style: configuration.style, color: tint(nil),
          samples: configuration.style == .sparkline
            ? store.history(provider: configuration.provider, windowID: id) : [],
          remaining: store.preferences.remaining, compact: true)
      }
      if revealed || configuration.style == .number || window?.usedPercent == nil {
        DigitFlipText(
          text: (window?.percent(remaining: store.preferences.remaining)
            .map { String(format: "%.0f", $0) } ?? "—") + (revealed ? "%" : ""),
          active: store.effectiveRefreshAnimation == .digitFlip && store.refreshAnimationActive,
          color: tint(window))
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
