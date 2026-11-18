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
  @State private var previewExpanded = false
  @State private var demoSettingsPresented = false
  @State private var columnVisibility: NavigationSplitViewVisibility = .all
  var body: some View {
    VStack(spacing: 0) {
      ZStack(alignment: .top) {
        if previewExpanded {
          previewHeader
            .transition(.move(edge: .top))
        }
      }
      .frame(height: previewExpanded ? previewHeight : 0, alignment: .top)
      .clipped()
      .allowsHitTesting(previewExpanded)
      .accessibilityHidden(!previewExpanded)
      .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: previewExpanded)
      settingsSplitView
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
            Text(T(store.preferences.isIslandVisible ? "隐藏" : "显示"))
          }
        }
        .buttonStyle(.borderless)
        .help(T("显示或隐藏灵动岛"))
        .disabled(store.preferences.islandHeadlinePlacement == nil)
        .accessibilityLabel(T("显示或隐藏灵动岛"))
        .accessibilityValue(T(store.preferences.isIslandVisible ? "已显示" : "已隐藏"))

        Button {
          AppDelegate.shared?.island?.toggleDetails()
        } label: {
          HStack(spacing: 6) {
            Image(systemName: islandState.expanded ? "chevron.up" : "chevron.down")
            Text(T(islandState.expanded ? "收起" : "详情"))
          }
        }
        .buttonStyle(.borderless)
        .disabled(store.preferences.islandHeadlinePlacement == nil)
        .help(T(islandState.expanded ? "收起灵动岛详情" : "显示灵动岛详情"))
        .accessibilityLabel(T(islandState.expanded ? "收起灵动岛详情" : "显示灵动岛详情"))

        Button {
          previewExpanded.toggle()
          if !previewExpanded { demoSettingsPresented = false }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: previewExpanded ? "eye" : "eye.slash")
            Text(T("预览"))
          }
        }
        .buttonStyle(.borderless)
        .help(T(previewExpanded ? "收起预览区域" : "展开预览区域"))
        .accessibilityLabel(T("预览"))
        .accessibilityValue(T(previewExpanded ? "已显示" : "已隐藏"))
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

  private var previewHeight: CGFloat { islandState.headlineHeight + 20 }

  private var previewHeader: some View {
    IslandPreview(store: store, islandState: islandState)
      .frame(minWidth: 0, maxWidth: .infinity)
      .frame(height: previewHeight)
      .overlay(alignment: .leading) {
        Text(T("预览区域"))
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.leading, 16)
          .allowsHitTesting(false)
      }
      .overlay(alignment: .trailing) {
        Button {
          demoSettingsPresented.toggle()
        } label: {
          Image(systemName: "ellipsis.circle")
        }
        .buttonStyle(.borderless)
        .help(T("演示预览"))
        .accessibilityLabel(T("演示预览"))
        .popover(isPresented: $demoSettingsPresented, arrowEdge: .bottom) {
          previewPopover
        }
        .padding(.trailing, 16)
      }
      .overlay(alignment: .bottom) { Divider() }
  }

  private var settingsSplitView: some View {
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
      ScrollView {
        detailContent
          .padding(30)
          .frame(maxWidth: 1040)
          .frame(maxWidth: .infinity)
      }
    }
  }

  private var previewPopover: some View {
    VStack(alignment: .leading, spacing: 14) {
      Toggle(T("使用演示数据预览样式"), isOn: Binding(get: { store.demoMode }, set: { store.setDemo($0) }))
      VStack(alignment: .leading, spacing: 8) {
        Text(T("演示剩余额度")).font(.caption).foregroundStyle(.secondary)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
          ForEach(DemoPreset.allCases) { preset in
            TileChoice(
              selection: Binding(get: { store.demoPreset }, set: { store.setDemoPreset($0) }),
              value: preset
            ) { Text(T(preset.rawValue)) }
          }
        }
      }
      Text(T("橙色、红色档位直接预览对应告警颜色；选择随机数据可为各平台生成不同的额度与趋势，再次点击可重新生成。"))
        .font(.caption).foregroundStyle(.secondary)
    }
    .padding(16)
    .frame(width: 560)
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


  @ViewBuilder
  private func providerRow(_ provider: Provider) -> some View {
    let enabled = store.preferences.enabled.contains(provider)
    let connected = store.readings[provider].map { $0.source != "未连接" } ?? false
    let row = HStack(spacing: 9) {
      ProviderIcon(
        provider: provider, size: 17,
        color: enabled ? store.preferences.providerColor(provider) : .secondary)
      Text(provider.name).lineLimit(1)
      Spacer(minLength: 4)
      Circle()
        .fill(enabled && connected ? store.preferences.providerColor(provider) : .secondary.opacity(0.28))
        .frame(width: 7, height: 7)
    }
    .font(.body)
    .foregroundStyle(enabled ? .primary : .secondary)
    .help(T("管理提供商"))
    if enabled {
      row
        .background {
          IslandProviderLayoutRegion(role: .source(provider, click: {
            selection = .provider(provider)
          }, previewColor: store.preferences.providerColor(provider)))
        }
        .contextMenu {
          Button(T("移到左侧")) { store.preferences.placeIslandProvider(provider, on: .left) }
          Button(T("移到右侧")) { store.preferences.placeIslandProvider(provider, on: .right) }
        }
    } else {
      row
    }
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
  @ObservedObject var islandState: IslandState
  var body: some View {
    let compact = islandState.headlineLayout(store.preferences, revealed: false)
    let revealed = islandState.headlineLayout(store.preferences, revealed: true)
    let layout = hovering ? revealed : compact
    let notchWidth = islandState.notchWidth
    let height = islandState.headlineHeight
    let accessoryWidth = islandState.sparkleWidth(store.preferences)
    let leadingAccessory = layout.placement == .left ? accessoryWidth : 0
    let trailingAccessory = accessoryWidth - leadingAccessory
    let leadingWidth = layout.leadingWidth + leadingAccessory
    let trailingWidth = layout.trailingWidth + trailingAccessory
    let sideExtent = max(
      max(compact.leadingWidth, revealed.leadingWidth) + leadingAccessory,
      max(compact.trailingWidth, revealed.trailingWidth) + trailingAccessory)

    Group {
      if let placement = layout.placement {
        let shape = IslandShape(expanded: false, notchAttachment: IslandNotchAttachment(placement))
        HStack(spacing: 0) {
          if placement == .left { Color.clear.frame(width: accessoryWidth) }
          IslandHeadlines(store: store, revealed: hovering, items: layout.leading, outerEdge: .leading)
          nativeNotch.frame(width: notchWidth, height: height)
          IslandHeadlines(store: store, revealed: hovering, items: layout.trailing, outerEdge: .trailing)
          if placement != .left { Color.clear.frame(width: accessoryWidth) }
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(height: height)
        .environment(\.colorScheme, .dark)
        .background(.black, in: shape)
        .clipShape(shape)
        .overlay(shape.stroke(.white.opacity(0.12)))
        .offset(x: (trailingWidth - leadingWidth) / 2)
      } else {
        nativeNotch.frame(width: notchWidth, height: height)
      }
    }
    .frame(width: notchWidth + 2 * sideExtent, height: height)
    .contentShape(Rectangle())
    .onHover { hovering = $0 }
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: hovering)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(T("预览"))
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
      .accessibilityLabel(T("Mac 刘海区域"))
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
