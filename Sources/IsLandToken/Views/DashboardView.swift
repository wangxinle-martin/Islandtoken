import IslandCore
import SwiftUI

enum DashboardPage: String, CaseIterable, Identifiable {
  case overview = "用量总览"
  case island = "灵动岛"
  case providers = "数据源"
  case history = "历史与费用"
  case general = "通用设置"
  var id: String { rawValue }
  var symbol: String {
    switch self {
    case .overview: "square.grid.2x2"
    case .island: "capsule"
    case .providers: "link"
    case .history: "chart.xyaxis.line"
    case .general: "gearshape"
    }
  }
}
struct DashboardView: View {
  @ObservedObject var store: AppStore
  @State private var page: DashboardPage? = .overview
  var body: some View {
    NavigationSplitView {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 10) {
          Image(systemName: "capsule.inset.filled").font(.system(size: 25)).foregroundStyle(.mint)
          VStack(alignment: .leading, spacing: 3) {
            Text("IsLandToken").font(.system(size: 15, weight: .semibold))
            Text("每一份额度，心中有数").font(.system(size: 9)).foregroundStyle(.secondary)
          }
        }.padding(.horizontal, 18).padding(.top, 24).padding(.bottom, 25)
        List(DashboardPage.allCases, selection: $page) { item in
          Label(item.rawValue, systemImage: item.symbol).tag(item).padding(.vertical, 5)
        }.listStyle(.sidebar)
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 6) {
            StatusDot(good: !store.demoMode)
            Text(store.demoMode ? "演示模式" : "本地优先 · 原生 macOS").font(.system(size: 10))
          }
          Text("VERSION 0.1.0").font(.system(size: 8, design: .monospaced)).tracking(1.5)
            .foregroundStyle(.tertiary)
        }.padding(20)
      }.navigationSplitViewColumnWidth(min: 195, ideal: 210, max: 240)
    } detail: {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          header
          if store.demoMode {
            HStack {
              Label("演示模式：以下额度和趋势均为示例", systemImage: "testtube.2")
              Spacer()
              Button("返回实时数据") { store.setDemo(false) }
            }
            .font(.callout).padding(12).background(
              .orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
          }
          if let notice = store.notice { Text(notice).font(.callout).foregroundStyle(.orange) }
          switch page ?? .overview {
          case .overview: overview
          case .island: IslandSettingsView(store: store)
          case .providers: ProviderSettingsView(store: store)
          case .history: HistoryView(store: store)
          case .general: GeneralSettingsView(store: store)
          }
        }.padding(30).frame(maxWidth: 1040)
          .frame(maxWidth: .infinity)
      }
    }
    .frame(minWidth: 900, minHeight: 660)
    .toolbar {
      ToolbarItemGroup {
        if store.refreshing { ProgressView().controlSize(.small) }
        Button {
          Task {
            await store.refresh()
            store.schedule()
          }
        } label: {
          Label("刷新", systemImage: "arrow.clockwise")
        }.disabled(store.refreshing || store.demoMode).help("刷新数据 ⌘R").keyboardShortcut("r")
        Button {
          AppDelegate.shared?.island?.toggleExpanded()
        } label: {
          Label("显示灵动岛", systemImage: "capsule")
        }.help("展开灵动岛")
      }
    }
  }
  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("YOUR AI, AT A GLANCE").font(.system(size: 9, weight: .medium, design: .monospaced))
        .tracking(2.6).foregroundStyle(.secondary)
      HStack(alignment: .firstTextBaseline) {
        Text(page?.rawValue ?? "用量总览").font(.system(size: 28, weight: .semibold))
        Spacer()
        if let next = store.nextRefresh, !store.demoMode {
          Text("下次同步 \(next.formatted(date: .omitted, time: .shortened))").font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
      }
      Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
    }
  }
  private var subtitle: String {
    switch page ?? .overview {
    case .overview: "从屏幕顶端，到每一个模型。让用量一目了然。"
    case .island: "左右两侧，各有偏好。所有调整即时生效。"
    case .providers: "接入熟悉的平台，沿用已有的登录状态。"
    case .history: "用真实记录观察变化，让下一次使用更从容。"
    case .general: "调整刷新、告警和启动方式。"
    }
  }
  private var overview: some View {
    VStack(alignment: .leading, spacing: 22) {
      IslandPreview(store: store)
      HStack {
        Text("已关注的平台").font(.system(size: 14, weight: .semibold))
        Text("\(store.preferences.providersToFetch.count)").font(
          .system(size: 10, design: .monospaced)
        ).foregroundStyle(.secondary)
        Spacer()
        Button("管理数据源 →") { page = .providers }.buttonStyle(.plain).font(.system(size: 11))
          .foregroundStyle(.secondary)
      }
      LazyVGrid(
        columns: [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)],
        spacing: 14
      ) {
        ForEach(store.preferences.providersToFetch) { provider in
          ProviderCard(store: store, provider: provider)
        }
      }
      HStack(alignment: .top, spacing: 9) {
        Image(systemName: "info.circle").foregroundStyle(.secondary)
        Text("订阅平台通常提供额度百分比，不提供可用 Token 总数。这里按平台原始口径显示剩余额度；Token 消耗与费用可在「历史与费用」查看。").font(
          .system(size: 11)
        ).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

struct IslandPreview: View {
  @State private var hovering = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @ObservedObject var store: AppStore
  var body: some View {
    ZStack {
      VStack(spacing: 23) {
        HStack {
          Text("LIVE PREVIEW").font(.system(size: 8, weight: .medium, design: .monospaced))
            .tracking(2)
          Spacer()
          Text(store.demoMode ? "示例" : "与你的灵动岛同步").font(.system(size: 9))
        }.foregroundStyle(.white.opacity(0.4))
        ZStack {
          HStack(spacing: 0) {
            if store.preferences.islandSideVisibility == .left {
              PairedHeadlines(store: store, revealed: hovering)
                .frame(
                  width: previewWidth(store.preferences.left)
                    + previewWidth(store.preferences.right))
            } else if store.preferences.islandSideVisibility == .both {
              SideHeadline(store: store, configuration: store.preferences.left, revealed: hovering)
                .frame(width: previewWidth(store.preferences.left))
            }
            Capsule().fill(.white.opacity(0.055)).frame(width: 92, height: 23).overlay(
              Circle().fill(.white.opacity(0.08)).frame(width: 6).offset(x: 24))
            if store.preferences.islandSideVisibility == .right {
              PairedHeadlines(store: store, revealed: hovering)
                .frame(
                  width: previewWidth(store.preferences.left)
                    + previewWidth(store.preferences.right))
            } else if store.preferences.islandSideVisibility == .both {
              SideHeadline(store: store, configuration: store.preferences.right, revealed: hovering)
                .frame(width: previewWidth(store.preferences.right))
            }
          }
        }.padding(.vertical, 13).background(.black, in: IslandShape(expanded: false))
          .overlay(IslandShape(expanded: false).stroke(.white.opacity(0.12)))
          .shadow(color: .mint.opacity(0.08), radius: 18, y: 6)
          .onHover { hovering = $0 }
          .animation(
            reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.62), value: hovering)
        HStack(spacing: 20) {
          Label("两侧独立配置", systemImage: "arrow.left.arrow.right")
          Label("点击展开", systemImage: "cursorarrow.click")
          Label("\(store.refreshDescription)同步", systemImage: "arrow.triangle.2.circlepath")
        }.font(.system(size: 9)).foregroundStyle(.white.opacity(0.45))
      }.padding(22).frame(maxWidth: .infinity)
        .background(
          LinearGradient(
            colors: [
              Color(red: 0.08, green: 0.10, blue: 0.12),
              Color(red: 0.045, green: 0.055, blue: 0.06),
            ], startPoint: .topLeading, endPoint: .bottomTrailing),
          in: RoundedRectangle(cornerRadius: 18)
        )
        .environment(\.colorScheme, .dark)
    }
    .clipShape(RoundedRectangle(cornerRadius: 18))
  }
  private func previewWidth(_ side: SideConfiguration) -> CGFloat {
    guard hovering else { return side.style == .dualPeriod ? 80 : 48 }
    return max(
      store.preferences.sideWidth,
      (side.style == .dualPeriod ? 130 : 150) + (side.showName ? 65 : 0))
  }
}

struct ProviderCard: View {
  @ObservedObject var store: AppStore
  var provider: Provider
  var body: some View {
    let reading = store.readings[provider]
    Surface {
      VStack(alignment: .leading, spacing: 17) {
        HStack {
          ProviderIcon(provider: provider, size: 26)
          Text(provider.name).font(.system(size: 14, weight: .semibold))
          Spacer()
          StatusDot(
            good: reading != nil
              && reading?.stale(refreshMinutes: store.effectiveRefreshMinutes) == false)
        }
        if let windows = reading?.windows, !windows.isEmpty {
          ForEach(Array(windows.prefix(3))) { window in
            VStack(alignment: .leading, spacing: 7) {
              HStack(alignment: .firstTextBaseline) {
                Text(window.title).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text(
                  window.percent(remaining: store.preferences.remaining).map {
                    String(format: "%.0f%%", $0)
                  } ?? "—"
                ).font(.system(size: 22, weight: .medium, design: .rounded)).monospacedDigit()
              }
              GeometryReader { geometry in
                Capsule().fill(provider.color.opacity(0.38)).overlay(alignment: .leading) {
                  Capsule().fill(provider.color).frame(
                    width: geometry.size.width
                      * (window.percent(remaining: store.preferences.remaining) ?? 0) / 100)
                }
              }.frame(height: 4)
              ResetLabel(window: window, absolute: store.preferences.absoluteResetTime)
            }
          }
        } else {
          Text("—").font(.system(size: 36, weight: .light)).foregroundStyle(.secondary)
          Text(store.refreshing ? "正在读取平台额度…" : "等待连接").font(.system(size: 11)).foregroundStyle(
            .secondary)
        }
        if let error = reading?.error {
          Text(error).font(.system(size: 10)).foregroundStyle(.orange).fixedSize(
            horizontal: false, vertical: true)
        } else if reading?.stale(refreshMinutes: store.effectiveRefreshMinutes) == true {
          Text("上次缓存 · 等待同步").font(.system(size: 10)).foregroundStyle(.orange)
        }
        if let credits = reading?.credits {
          Text("可用积分 \(credits.formatted())").font(.system(size: 10)).foregroundStyle(.secondary)
        }
        HStack {
          Text(reading?.source ?? "尚未同步").lineLimit(1)
          Spacer()
          if let reading, !reading.windows.isEmpty { Text(reading.updatedAt, style: .time) }
        }.font(.system(size: 8)).foregroundStyle(.tertiary)
      }.frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
    }
    .contextMenu { Link("打开平台用量页", destination: provider.dashboard) }
  }
}
