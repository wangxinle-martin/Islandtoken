import IslandCore
import SwiftUI

struct IslandView: View {
  @ObservedObject var store: AppStore
  @ObservedObject var state: IslandState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 0) {
        Button {
          guard store.preferences.clickExpand || state.expanded else { return }
          state.expanded.toggle()
          if !state.expanded { state.pinned = false }
        } label: {
          HStack(spacing: 0) {
            if store.preferences.islandSideVisibility == .left { sparkleSlot }
            if store.preferences.islandSideVisibility != .right {
              Group {
                if store.preferences.islandSideVisibility == .left {
                  PairedHeadlines(store: store, revealed: state.headlineRevealed)
                } else {
                  SideHeadline(
                    store: store, configuration: store.preferences.left,
                    revealed: state.headlineRevealed)
                }
              }.frame(
                width: state.leftWidth(store.preferences)
                  + state.leftHeaderExpansion(store.preferences)
                  - state.centeredCompactInset(store.preferences)
                  - (store.preferences.islandSideVisibility == .left
                    ? state.sparkleWidth(store.preferences) : 0)
                  + state.singleExpandedInset(store.preferences),
                alignment: store.effectiveRefreshAnimation == .sparkle
                  && state.refreshAnimationActive
                  && store.preferences.islandSideVisibility == .left ? .leading : .center
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
                  PairedHeadlines(store: store, revealed: state.headlineRevealed)
                } else {
                  SideHeadline(
                    store: store, configuration: store.preferences.right,
                    revealed: state.headlineRevealed)
                }
              }.frame(
                width: state.rightWidth(store.preferences)
                  + state.rightHeaderExpansion(store.preferences)
                  - state.sparkleWidth(store.preferences)
                  - state.centeredCompactInset(store.preferences),
                alignment: store.effectiveRefreshAnimation == .sparkle
                  && state.refreshAnimationActive ? .trailing : .center
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
          Button("打开控制台") { AppDelegate.shared?.showDashboard() }
          Button("立即刷新") {
            Task {
              await store.refresh()
              store.schedule()
            }
          }.keyboardShortcut("r", modifiers: .command)
          Button("左右互换") {
            let left = store.preferences.left
            store.preferences.left = store.preferences.right
            store.preferences.right = left
          }
          Divider()
          Button("退出 IsLandToken") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
          state.expanded
            ? "收起 IsLandToken" : store.preferences.clickExpand ? "展开 IsLandToken" : "IsLandToken 额度"
        )
        if state.expanded {
          expanded
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
      .frame(width: state.width(store.preferences), height: state.height, alignment: .top)
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

  private var expanded: some View {
    CodexBarPopupView(store: store, state: state)
  }

}

struct PairedHeadlines: View {
  @ObservedObject var store: AppStore
  var revealed: Bool
  var body: some View {
    HStack(spacing: 12) {
      SideHeadline(store: store, configuration: store.preferences.left, revealed: revealed)
      SideHeadline(store: store, configuration: store.preferences.right, revealed: revealed)
    }
  }
}

struct SideHeadline: View {
  @ObservedObject var store: AppStore
  var configuration: SideConfiguration
  var revealed = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    let reading = store.readings[configuration.provider]
    let stale = reading?.stale(refreshMinutes: store.effectiveRefreshMinutes) ?? true
    Group {
      if revealed {
        ScrollView(.horizontal) {
          headlineContent(reading: reading, stale: stale)
            // Match the 28pt safety allowance in IslandState.sideWidth.
            // Scroll views otherwise place their content directly against
            // the viewport edge, where the expanded island corner clips it.
            .padding(.horizontal, 14)
        }
        .scrollIndicators(.hidden)
      } else {
        // In the minimum state, use the selected quotas' intrinsic width.
        // A ScrollView has a flexible viewport and can compress the first
        // value into the island corner before the outer frame catches up.
        headlineContent(reading: reading, stale: stale)
          .fixedSize(horizontal: true, vertical: false)
      }
    }
    .frame(height: 20)
    .help("\(configuration.provider.name) · " + configuration.windowIDs.map {
      reading?.window($0)?.title ?? $0
    }.joined(separator: " / ") + (stale ? " · 数据待更新" : ""))
  }
  private func headlineContent(reading: UsageReading?, stale: Bool) -> some View {
    HStack(spacing: 4) {
      if revealed && configuration.showIcon {
        ProviderIcon(provider: configuration.provider, size: 13, color: tint(nil))
      }
      if revealed && configuration.showName {
        Text(configuration.provider == .antigravity ? "Anti" : configuration.provider.name)
          .font(.system(size: 9)).lineLimit(1)
      }
      ForEach(Array(configuration.windowIDs.enumerated()), id: \.element) { index, id in
        if index > 0 {
          Text("|").font(.system(size: 12, weight: .semibold)).foregroundStyle(tint(nil))
        }
        quota(reading?.window(id), id: id)
          .help(reading?.window(id)?.title ?? "\(id) · 暂无额度")
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
          samples: store.history(provider: configuration.provider, windowID: id),
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
    return configuration.accent.color(for: configuration.provider)
  }
}
