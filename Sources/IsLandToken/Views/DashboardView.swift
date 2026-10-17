import IslandCore
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
  case general = "通用"
  case overview = "用量"
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
  @ObservedObject var islandState: IslandState
  @AppStorage("interfaceLanguage") private var interfaceLanguage = InterfaceLanguage.chinese.rawValue
  @AppStorage("providerSortOrder") private var providerSortOrder = ProviderSortOrder.alphabetically.rawValue
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var selection: SidebarSelection? = .page(.general)
  @State private var providerSearch = ""
  @State private var columnVisibility: NavigationSplitViewVisibility = .all
  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
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
      if selectedPage == .island {
        VStack(spacing: 0) {
          IslandPreview(store: store)
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 10)
            .frame(maxWidth: 1040)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
          ScrollView {
            detailContent
              .padding(30)
              .frame(maxWidth: 1040)
              .frame(maxWidth: .infinity)
          }
        }
      } else {
        ScrollView {
          detailContent
            .padding(30)
            .frame(maxWidth: 1040)
            .frame(maxWidth: .infinity)
        }
      }
    }
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: columnVisibility)
    .frame(minWidth: 900, minHeight: 660)
    .toolbar {
      ToolbarItemGroup(placement: .navigation) {
        Rectangle()
          .fill(Color.secondary.opacity(0.45))
          .frame(width: 1, height: 32)

        Button {
          let target: NavigationSplitViewVisibility =
            columnVisibility == .detailOnly ? .all : .detailOnly
          if reduceMotion {
            columnVisibility = target
          } else {
            withAnimation(.easeInOut(duration: 0.28)) {
              columnVisibility = target
            }
          }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "sidebar.leading")
              .contentTransition(.symbolEffect(.replace))
            Text(T(columnVisibility == .detailOnly ? "展开" : "收缩"))
              .contentTransition(.opacity)
          }
        }
        .buttonStyle(.borderless)
        .help(T(columnVisibility == .detailOnly ? "展开左侧菜单" : "收起左侧菜单"))

        Button {
          Task {
            await store.refresh()
            store.schedule()
          }
        } label: {
          HStack(spacing: 6) {
            TimelineView(.animation(paused: !store.refreshing)) { context in
              Image(systemName: "arrow.clockwise")
                .rotationEffect(.degrees(store.refreshing
                  ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1) * 360
                  : 0))
            }
            Text(T("刷新"))
          }
        }
        .buttonStyle(.borderless)
        .disabled(store.refreshing || store.demoMode).help(T("刷新数据 ⌘R")).keyboardShortcut("r")

        Button {
          store.preferences.showIsland.toggle()
        } label: {
          HStack(spacing: 6) {
            IslandIcon().stroke(.primary, lineWidth: 1.5).frame(width: 18, height: 12)
            Text(T(store.preferences.showIsland ? "隐藏" : "显示"))
          }
        }
        .buttonStyle(.borderless)
        .help(T("显示或隐藏灵动岛"))
        .accessibilityLabel(T("显示或隐藏灵动岛"))
        .accessibilityValue(T(store.preferences.showIsland ? "已显示" : "已隐藏"))

        Button {
          AppDelegate.shared?.island?.toggleDetails()
        } label: {
          HStack(spacing: 6) {
            Image(systemName: islandState.expanded ? "chevron.up" : "chevron.down")
            Text(T(islandState.expanded ? "收起" : "详情"))
          }
        }
        .buttonStyle(.borderless)
        .help(T(islandState.expanded ? "收起灵动岛详情" : "显示灵动岛详情"))
        .accessibilityLabel(T(islandState.expanded ? "收起灵动岛详情" : "显示灵动岛详情"))
      }
    }
    .toolbar(removing: .sidebarToggle)
    .toolbarRole(.editor)
    // Keep the split view transparent enough for the AppKit material behind it
    // to provide the system glass depth through the toolbar and content areas.
    .background(.thinMaterial)
    // `T(...)` reads UserDefaults directly, so make the stored language an explicit
    // SwiftUI dependency and rebuild the settings tree when it changes.
    .id(interfaceLanguage)
  }

  @ViewBuilder
  private var detailContent: some View {
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
      if let notice = store.notice {
        Text(UserFacingText.value(notice)).font(.callout).foregroundStyle(.orange)
      }
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
    Surface {
      ZStack(alignment: .top) {
        Text(T("预览"))
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
        HStack(spacing: 0) {
        if store.preferences.islandSideVisibility == .left {
          PairedHeadlines(
            store: store, revealed: hovering,
            leftWidth: previewWidth(
              store.preferences.left, horizontalPadding: headlineInsets.leading,
              reservesRevealedSafety: true),
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
              store.preferences.left, horizontalPadding: headlineInsets.leading,
              reservesRevealedSafety: true))
        }
        Color.clear.frame(width: nativeNotchSize.width, height: nativeNotchSize.height)
        if store.preferences.islandSideVisibility == .right {
          PairedHeadlines(
            store: store, revealed: hovering,
            leftWidth: previewWidth(store.preferences.left, horizontalPadding: 0),
            rightWidth: previewWidth(
              store.preferences.right, horizontalPadding: headlineInsets.trailing,
              reservesRevealedSafety: true),
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
              store.preferences.right, horizontalPadding: headlineInsets.trailing,
              reservesRevealedSafety: true))
        }
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(height: nativeNotchSize.height)
        .environment(\.colorScheme, .dark)
        .background(.black, in: IslandShape(expanded: false, notchAttachment: notchAttachment))
        .clipShape(IslandShape(expanded: false, notchAttachment: notchAttachment))
        .overlay(
          IslandShape(expanded: false, notchAttachment: notchAttachment).stroke(.white.opacity(0.12)))
        .shadow(color: .mint.opacity(0.08), radius: 18, y: 6)
        .offset(x: (sideWidths.right - sideWidths.left) / 2)
        nativeNotch
          .allowsHitTesting(false)
      }
      .frame(maxWidth: .infinity)
      .frame(height: previewHeight, alignment: .top)
      .onHover { hovering = $0 }
      .animation(
        reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.62), value: hovering)
    }
  }

  private var previewHeight: CGFloat { nativeNotchSize.height * 1.5 }

  private var notchAttachment: IslandNotchAttachment {
    IslandNotchAttachment(store.preferences.islandSideVisibility)
  }

  private var nativeNotch: some View {
    UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10)
      .fill(.black)
      .overlay {
        UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10)
          .strokeBorder(.orange.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
      }
      .overlay {
        Text(T("刘海区域"))
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.white.opacity(0.5))
      }
      .frame(width: nativeNotchSize.width, height: nativeNotchSize.height)
      .accessibilityLabel(T("Mac 刘海区域"))
  }
  private var nativeNotchSize: CGSize {
    let screen = NSScreen.screens.first { String($0.displayID) == store.preferences.screenID }
      ?? NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    if let screen, screen.safeAreaInsets.top > 0,
      let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea,
      right.minX > left.maxX
    {
      return CGSize(width: right.minX - left.maxX, height: screen.safeAreaInsets.top)
    }
    return CGSize(width: 200, height: 32)
  }
  private func previewWidth(
    _ side: SideConfiguration, horizontalPadding: CGFloat = 0,
    reservesRevealedSafety: Bool = false
  ) -> CGFloat {
    let reading = store.readings[side.provider]
    let width = IslandState.measuredSideWidth(
      side, reading: reading, remaining: store.preferences.remaining, revealed: hovering,
      horizontalPadding: horizontalPadding,
      showsStatusDot: hovering && !store.demoMode
        && (reading?.stale(refreshMinutes: store.effectiveRefreshMinutes) ?? true))
    return width + (hovering && reservesRevealedSafety
      ? CGFloat(IslandHeadlineInsets.revealedLeadingContentSafety) : 0)
  }

  private var sideWidths: (left: CGFloat, right: CGFloat) {
    switch store.preferences.islandSideVisibility {
    case .left:
      return (
        previewWidth(store.preferences.left, horizontalPadding: headlineInsets.leading)
          + revealedSafety
          + previewWidth(store.preferences.right) + IslandState.pairedHeadlineSpacing,
        0
      )
    case .both:
      return (
        previewWidth(store.preferences.left, horizontalPadding: headlineInsets.leading)
          + revealedSafety,
        previewWidth(store.preferences.right, horizontalPadding: headlineInsets.trailing)
          + revealedSafety
      )
    case .right:
      return (
        0,
        previewWidth(store.preferences.left)
          + previewWidth(store.preferences.right, horizontalPadding: headlineInsets.trailing)
          + revealedSafety
          + IslandState.pairedHeadlineSpacing
      )
    }
  }

  private var revealedSafety: CGFloat {
    hovering ? CGFloat(IslandHeadlineInsets.revealedLeadingContentSafety) : 0
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
                Text(UserFacingText.quotaTitle(window.title))
                  .font(.system(size: 11)).foregroundStyle(.secondary)
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
          Text(UserFacingText.value(error)).font(.system(size: 10)).foregroundStyle(.orange).fixedSize(
            horizontal: false, vertical: true)
        } else if reading?.stale(refreshMinutes: store.effectiveRefreshMinutes) == true {
          Text(T("上次缓存 · 等待同步")).font(.system(size: 10)).foregroundStyle(.orange)
        }
        if let credits = reading?.credits {
          Text(T("可用积分 %@", credits.formatted())).font(.system(size: 10)).foregroundStyle(.secondary)
        }
        HStack {
          Text(reading.map { UserFacingText.source($0.source) } ?? T("尚未同步")).lineLimit(1)
          Spacer()
          if let reading, !reading.windows.isEmpty { Text(UserFacingText.time(reading.updatedAt)) }
        }.font(.system(size: 8)).foregroundStyle(.tertiary)
      }.frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
    }
    .contextMenu { Link(T("打开平台用量页"), destination: provider.dashboard) }
  }
}
