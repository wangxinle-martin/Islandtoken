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
    let window = reading?.window(configuration.windowID)
    let value = window?.percent(remaining: store.preferences.remaining)
    let stale = reading?.stale(refreshMinutes: store.effectiveRefreshMinutes) ?? true
    HStack(spacing: 4) {
      if revealed && configuration.showIcon {
        ProviderIcon(provider: configuration.provider, size: 13, color: tint(window))
          .transition(.scale(scale: 0.5).combined(with: .opacity))
      }
      Group {
        if revealed && configuration.showName {
          Text(configuration.provider == .antigravity ? "Anti" : configuration.provider.name).font(
            .system(size: 9)
          ).lineLimit(1)
        }
        if configuration.style != .number && configuration.style != .dualPeriod {
          QuotaGauge(
            value: value, style: configuration.style, color: tint(window),
            samples: store.history(
              provider: configuration.provider, windowID: configuration.windowID),
            remaining: store.preferences.remaining, compact: true)
        }
        if revealed || configuration.style == .number || configuration.style == .dualPeriod {
          HStack(alignment: .firstTextBaseline, spacing: 0) {
            DigitFlipText(
              text: configuration.headlineText(
                reading: reading, remaining: store.preferences.remaining, revealed: revealed),
              active: store.effectiveRefreshAnimation == .digitFlip
                && store.refreshAnimationActive, color: tint(window))
            if revealed && configuration.style != .dualPeriod {
              Text("%").font(.system(size: 10, weight: .semibold)).foregroundStyle(tint(window))
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
          }
          if revealed && stale && !store.demoMode {
            Circle().fill(.orange).frame(width: 3, height: 3)
          }
        }
      }
    }.fixedSize(horizontal: true, vertical: false).opacity(stale && !store.demoMode ? 0.65 : 1)
      .animation(
        reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.55), value: revealed
      )
      .help(
        "\(configuration.provider.name) · \(configuration.style == .dualPeriod ? "5 小时 / 一周" : window?.title ?? "尚无额度")\(stale ? " · 数据待更新" : "")"
      )
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
