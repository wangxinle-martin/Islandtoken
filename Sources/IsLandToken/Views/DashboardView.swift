import IslandCore
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
  case general = "通用"
  case overview = "用量总览"
  case island = "灵动岛"
  case about = "关于"
  var id: String { rawValue }
  var title: String { T(rawValue) }
  var symbol: String {
    switch self {
    case .general: "gearshape"
    case .overview: "square.grid.2x2"
    case .island: "capsule"
    case .about: "info.circle"
    }
  }
}

/// A single native sidebar selection covers both application pages and providers.
/// This keeps all rows on the exact same List selection/rendering path.
enum SidebarSelection: Hashable {
  case page(SettingsPage)
  case provider(Provider)
}

enum ProviderSortOrder: String, CaseIterable, Identifiable {
  case alphabetically
  case enabledThenAlphabetically

  var id: String { rawValue }
  var title: String {
    switch self {
    case .alphabetically: T("按首字母")
    case .enabledThenAlphabetically: T("已开启优先")
    }
  }
}

struct DashboardView: View {
  @ObservedObject var store: AppStore
  @AppStorage("interfaceLanguage") private var interfaceLanguage = InterfaceLanguage.chinese.rawValue
  @AppStorage("providerSortOrder") private var providerSortOrder = ProviderSortOrder.alphabetically.rawValue
  @State private var selection: SidebarSelection? = .page(.general)
  @State private var providerSearch = ""
  var body: some View {
    NavigationSplitView {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 10) {
          IslandIcon().stroke(.mint, lineWidth: 2).frame(width: 28, height: 18)
          VStack(alignment: .leading, spacing: 3) {
            Text("IsLandToken").font(.system(size: 15, weight: .semibold))
            Text(T("每一份额度，心中有数")).font(.system(size: 9)).foregroundStyle(.secondary)
          }
        }.padding(.horizontal, 18).padding(.top, 24).padding(.bottom, 25)
        List(selection: $selection) {
          ForEach(SettingsPage.allCases) { item in
            pageRow(item)
              .tag(SidebarSelection.page(item))
              .padding(.vertical, 5)
          }
          // Keep the provider controls in a normal list row so macOS does not add
          // a hover-only disclosure button as it would for a sidebar Section.
          Group {
            HStack(spacing: 4) {
              ZStack(alignment: .trailing) {
                TextField(T("搜索提供商"), text: $providerSearch)
                  .textFieldStyle(.roundedBorder)
                  .padding(.trailing, providerSearch.isEmpty ? 0 : 26)
                if !providerSearch.isEmpty {
                  Button {
                    providerSearch = ""
                  } label: {
                    Image(systemName: "xmark.circle.fill")
                      .foregroundStyle(.secondary)
                  }
                  .buttonStyle(.plain)
                  .padding(.trailing, 7)
                  .help(T("清除搜索"))
                }
              }
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: 28)
                .layoutPriority(1)
              Button(action: toggleProviderSortOrder) {
                ProviderSortIcon(order: currentProviderSortOrder)
                  .frame(width: 28, height: 28)
                  .contentShape(Rectangle())
              }
              .buttonStyle(.borderless)
              .fixedSize()
              .help(
                currentProviderSortOrder == .alphabetically
                  ? T("当前：按首字母；点击切换为已开启优先")
                  : T("当前：已开启优先；点击切换为按首字母"))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
            ForEach(filteredProviders) { provider in
              providerRow(provider)
                .tag(SidebarSelection.provider(provider))
                .padding(.vertical, 5)
            }
          }
        }
        .listStyle(.sidebar)
      }.navigationSplitViewColumnWidth(min: 195, ideal: 210, max: 240)
    } detail: {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          if store.demoMode {
            HStack {
              Label(T("演示模式：以下额度和趋势均为示例"), systemImage: "testtube.2")
              Spacer()
              Button(T("返回实时数据")) { store.setDemo(false) }
            }
            .font(.callout).padding(12).background(
              .orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
          }
          if let notice = store.notice { Text(notice).font(.callout).foregroundStyle(.orange) }
          if case .provider(let provider) = selection {
            ProviderDetailView(store: store, provider: provider)
          } else {
            switch selectedPage {
            case .general: GeneralSettingsView(store: store)
            case .overview: overview
            case .island: IslandSettingsView(store: store)
            case .about: AboutSettingsView()
            }
          }
        }.padding(30).frame(maxWidth: 1040)
          .frame(maxWidth: .infinity)
      }
    }
    .frame(minWidth: 900, minHeight: 660)
    // `T(...)` reads UserDefaults directly, so make the stored language an explicit
    // SwiftUI dependency and rebuild the settings tree when it changes.
    .id(interfaceLanguage)
    .toolbar {
      ToolbarItemGroup {
        if store.refreshing { ProgressView().controlSize(.small) }
        Button {
          Task {
            await store.refresh()
            store.schedule()
          }
        } label: {
          Label(T("刷新"), systemImage: "arrow.clockwise")
        }.disabled(store.refreshing || store.demoMode).help(T("刷新数据 ⌘R")).keyboardShortcut("r")
        Button {
          AppDelegate.shared?.island?.toggleExpanded()
        } label: {
          HStack(spacing: 6) {
            IslandIcon().stroke(.primary, lineWidth: 1.5).frame(width: 18, height: 12)
            Text(T("显示灵动岛"))
          }
        }.help(T("展开灵动岛"))
      }
    }
  }
  private func providerRow(_ provider: Provider) -> some View {
    let enabled = store.preferences.enabled.contains(provider)
    return HStack(spacing: 9) {
      ProviderIcon(
        provider: provider, size: 17,
        color: enabled ? store.preferences.providerColor(provider) : .secondary)
      Text(provider.name).lineLimit(1)
      Spacer(minLength: 4)
      Circle()
        .fill(enabled ? store.preferences.providerColor(provider) : .secondary.opacity(0.28))
        .frame(width: 7, height: 7)
    }
    .font(.body)
    .foregroundStyle(enabled ? .primary : .secondary)
    .help(T("管理提供商"))
  }
  private func pageRow(_ item: SettingsPage) -> some View {
    Label {
      Text(item.title)
    } icon: {
      if item == .island {
        IslandIcon()
          .stroke(.primary, lineWidth: 1.5)
          .frame(width: 18, height: 11)
      } else {
        Image(systemName: item.symbol)
      }
    }
  }
  private var overview: some View {
    VStack(alignment: .leading, spacing: 22) {
      HStack {
        Text(T("已关注的平台")).font(.system(size: 14, weight: .semibold))
        Text("\(store.preferences.providersToFetch.count)").font(
          .system(size: 10, design: .monospaced)
        ).foregroundStyle(.secondary)
        Spacer()
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
        Text(T("订阅平台通常提供额度百分比，不提供可用 Token 总数。这里按平台原始口径显示剩余额度；Token 消耗与费用可在各提供商详情中查看。")).font(
          .system(size: 11)
        ).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var selectedPage: SettingsPage {
    if case .page(let page) = selection { return page }
    return .general
  }
  private var currentProviderSortOrder: ProviderSortOrder {
    ProviderSortOrder(rawValue: providerSortOrder) ?? .alphabetically
  }
  private func toggleProviderSortOrder() {
    providerSortOrder =
      currentProviderSortOrder == .alphabetically
      ? ProviderSortOrder.enabledThenAlphabetically.rawValue
      : ProviderSortOrder.alphabetically.rawValue
  }
  private var filteredProviders: [Provider] {
    let query = providerSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let matching = Provider.allCases.filter {
      query.isEmpty || $0.name.lowercased().contains(query) || $0.rawValue.contains(query)
    }
    return matching.sorted { lhs, rhs in
      if currentProviderSortOrder == .enabledThenAlphabetically {
        let leftEnabled = store.preferences.enabled.contains(lhs)
        let rightEnabled = store.preferences.enabled.contains(rhs)
        if leftEnabled != rightEnabled { return leftEnabled }
      }
      return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
  }
}

/// Supplied SVGs distinguish alphabetical sorting from enabled-provider-first sorting.
private struct ProviderSortIcon: View {
  let order: ProviderSortOrder

  private static let images: [ProviderSortOrder: NSImage] = Dictionary(
    uniqueKeysWithValues: ProviderSortOrder.allCases.compactMap { order in
      let name = order == .alphabetically ? "provider-sort-alphabetical" : "provider-sort-enabled"
      guard let url = AppResourceBundle.bundle.url(forResource: name, withExtension: "svg"),
        let image = NSImage(contentsOf: url)
      else { return nil }
      image.isTemplate = true
      return (order, image)
    })

  var body: some View {
    Group {
      if let image = Self.images[order] {
        Image(nsImage: image)
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .foregroundStyle(Color.blue)
      } else {
        Image(systemName: "line.3.horizontal.decrease.circle")
          .foregroundStyle(.blue)
      }
    }
    .frame(width: 20, height: 20)
    .accessibilityLabel(T(order == .alphabetically ? "按首字母" : "已开启优先"))
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
          Text(T("实时预览")).font(.system(size: 8, weight: .medium, design: .monospaced))
            .tracking(2)
          Spacer()
          Text(T(store.demoMode ? "示例" : "与你的灵动岛同步")).font(.system(size: 9))
        }.foregroundStyle(.white.opacity(0.4))
        HStack(spacing: 0) {
          if store.preferences.islandSideVisibility == .left {
            PairedHeadlines(
              store: store, revealed: hovering,
              leftWidth: previewWidth(
                store.preferences.left, horizontalPadding: headlineInsets.leading),
              rightWidth: previewWidth(store.preferences.right, horizontalPadding: 0),
              outerEdge: .leading, outerInset: headlineInsets.leading)
          } else if store.preferences.islandSideVisibility == .both {
            SideHeadline(
              store: store, configuration: store.preferences.left, revealed: hovering,
              leadingInset: headlineInsets.leading,
              revealedLeadingContentInset: CGFloat(
                IslandHeadlineInsets.revealedLeadingContentSafety),
              revealedAnchor: .leading
            )
            .frame(
              width: previewWidth(
                store.preferences.left, horizontalPadding: headlineInsets.leading))
          }
          Capsule().fill(.white.opacity(0.055)).frame(width: 92, height: 23).overlay(
            Circle().fill(.white.opacity(0.08)).frame(width: 6).offset(x: 24))
          if store.preferences.islandSideVisibility == .right {
            PairedHeadlines(
              store: store, revealed: hovering,
              leftWidth: previewWidth(store.preferences.left, horizontalPadding: 0),
              rightWidth: previewWidth(
                store.preferences.right, horizontalPadding: headlineInsets.trailing),
              outerEdge: .trailing, outerInset: headlineInsets.trailing)
          } else if store.preferences.islandSideVisibility == .both {
            SideHeadline(
              store: store, configuration: store.preferences.right, revealed: hovering,
              trailingInset: headlineInsets.trailing,
              revealedTrailingContentInset: CGFloat(
                IslandHeadlineInsets.revealedLeadingContentSafety),
              revealedAnchor: .trailing
            )
            .frame(
              width: previewWidth(
                store.preferences.right, horizontalPadding: headlineInsets.trailing))
          }
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding(.vertical, 13)
        .background(.black, in: IslandShape(expanded: false))
        .clipShape(IslandShape(expanded: false))
        .overlay(IslandShape(expanded: false).stroke(.white.opacity(0.12)))
        .shadow(color: .mint.opacity(0.08), radius: 18, y: 6)
        .onHover { hovering = $0 }
        .animation(
          reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.62), value: hovering)
        HStack(spacing: 20) {
          Label(T("两侧独立配置"), systemImage: "arrow.left.arrow.right")
          Label(T("点击展开"), systemImage: "cursorarrow.click")
          Label(T("%@同步", T(store.refreshDescription)), systemImage: "arrow.triangle.2.circlepath")
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
  private func previewWidth(
    _ side: SideConfiguration, horizontalPadding: CGFloat = 0
  ) -> CGFloat {
    let reading = store.readings[side.provider]
    return IslandState.measuredSideWidth(
      side, reading: reading, remaining: store.preferences.remaining, revealed: hovering,
      horizontalPadding: horizontalPadding,
      showsStatusDot: hovering && !store.demoMode
        && (reading?.stale(refreshMinutes: store.effectiveRefreshMinutes) ?? true))
  }

  private var headlineInsets: (leading: CGFloat, trailing: CGFloat) {
    let insets = IslandHeadlineInsets.resolve(
      for: store.preferences.islandSideVisibility, isMinimum: !hovering)
    return (CGFloat(insets.leading), CGFloat(insets.trailing))
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
          ProviderIcon(provider: provider, size: 26, color: store.preferences.providerColor(provider))
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
                Capsule().fill(store.preferences.providerColor(provider).opacity(0.38)).overlay(alignment: .leading) {
                  Capsule().fill(store.preferences.providerColor(provider)).frame(
                    width: geometry.size.width
                      * (window.percent(remaining: store.preferences.remaining) ?? 0) / 100)
                }
              }.frame(height: 4)
              ResetLabel(window: window, absolute: store.preferences.absoluteResetTime)
            }
          }
        } else {
          Text("—").font(.system(size: 36, weight: .light)).foregroundStyle(.secondary)
          Text(T(store.refreshing ? "正在读取平台额度…" : "等待连接")).font(.system(size: 11)).foregroundStyle(
            .secondary)
        }
        if let error = reading?.error {
          Text(error).font(.system(size: 10)).foregroundStyle(.orange).fixedSize(
            horizontal: false, vertical: true)
        } else if reading?.stale(refreshMinutes: store.effectiveRefreshMinutes) == true {
          Text(T("上次缓存 · 等待同步")).font(.system(size: 10)).foregroundStyle(.orange)
        }
        if let credits = reading?.credits {
          Text(T("可用积分 %@", credits.formatted())).font(.system(size: 10)).foregroundStyle(.secondary)
        }
        HStack {
          Text(T(reading?.source ?? "尚未同步")).lineLimit(1)
          Spacer()
          if let reading, !reading.windows.isEmpty { Text(reading.updatedAt, style: .time) }
        }.font(.system(size: 8)).foregroundStyle(.tertiary)
      }.frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
    }
    .contextMenu { Link(T("打开平台用量页"), destination: provider.dashboard) }
  }
}
