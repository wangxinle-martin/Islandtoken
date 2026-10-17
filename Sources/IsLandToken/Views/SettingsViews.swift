import IslandCore
import ServiceManagement
import SwiftUI

struct IslandSettingsView: View {
  @ObservedObject var store: AppStore
  var body: some View {
    LazyVStack(spacing: 22) {
      IslandSideSettings(store: store)
      SettingsSection(title: T("位置与屏幕")) {
        Toggle(T("显示灵动岛"), isOn: $store.preferences.showIsland)
        VStack(alignment: .leading, spacing: 8) {
          Text(T("灵动岛显示位置")).font(.caption).foregroundStyle(.secondary)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
            ForEach(IslandSideVisibility.allCases) { option in
              TileChoice(selection: $store.preferences.islandSideVisibility, value: option) {
                Text(T(option.title))
              }
            }
          }
        }
        Text(T("左侧或右侧模式将两个已选平台并排显示在刘海同一侧，另一侧宽度为零；两侧模式分别显示。")).font(.caption).foregroundStyle(
          .secondary)
        Text(T("最小状态按所选样式显示圆环、进度条、分段、数字或趋势；鼠标移入时显示数值、百分号及已启用的图标和名称。开启系统减少动态效果时不播放弹动。")).font(
          .caption
        ).foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 8) {
          Text(T("显示器")).font(.caption).foregroundStyle(.secondary)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
            TileChoice(selection: $store.preferences.screenID, value: "auto") {
              Text(T("自动 · 优先刘海屏"))
            }
            ForEach(NSScreen.screens, id: \.displayID) { screen in
              TileChoice(selection: $store.preferences.screenID, value: String(screen.displayID)) {
                Text(screen.localizedName)
              }
            }
            if store.preferences.screenID != "auto"
              && !NSScreen.screens.contains(where: {
                String($0.displayID) == store.preferences.screenID
              })
            {
              TileChoice(
                selection: $store.preferences.screenID, value: store.preferences.screenID
              ) { Text(T("已断开 · 自动回退")) }
            }
          }
        }
        SettingsRulerControl(title: "顶部偏移", value: $store.preferences.verticalOffset, range: 0...80)
        SettingsRulerControl(title: "水平偏移", value: $store.preferences.horizontalOffset, range: -1000...1000)
        Text(T("水平偏移负值向左、正值向右，靠近屏幕边缘时自动限位。"))
          .font(.caption).foregroundStyle(.secondary)
        Text(T("无刘海屏也可使用。若与菜单栏内容重叠，可增加顶部偏移；拔出指定显示器后会自动回退。")).font(.caption).foregroundStyle(
          .secondary)
      }
      SettingsSection(title: T("点击与悬停")) {
        VStack(alignment: .leading, spacing: 8) {
          Text(T("详情显示方式")).font(.caption).foregroundStyle(.secondary)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
            ForEach(DetailInteraction.allCases) { option in
              TileChoice(selection: $store.preferences.detailInteraction, value: option) {
                Text(T(option.title))
              }
            }
          }
        }
        Text(T("详情显示方式三选一。选择不显示详情时仍可悬停查看图标和百分号。菜单栏入口可在通用设置中配置。")).font(.caption).foregroundStyle(
          .secondary)
      }
      SettingsSection(title: T("额度与重置时间")) {
        VStack(alignment: .leading, spacing: 8) {
          Text(T("额度显示方式")).font(.caption).foregroundStyle(.secondary)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
            TileChoice(selection: $store.preferences.remaining, value: false) {
              Text(T("使用额度"))
            }
            TileChoice(selection: $store.preferences.remaining, value: true) {
              Text(T("剩余额度"))
            }
          }
        }
        VStack(alignment: .leading, spacing: 8) {
          Text(T("重置时间显示方式")).font(.caption).foregroundStyle(.secondary)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
            TileChoice(selection: $store.preferences.absoluteResetTime, value: false) {
              Text(T("倒计时"))
            }
            TileChoice(selection: $store.preferences.absoluteResetTime, value: true) {
              Text(T("日期与时间"))
            }
          }
        }
        Text(T("完整时间按 Mac 当前时区显示，例如 重置于 09月09日 18:30。未提供重置时间的平台仍显示原提示。")).font(.caption)
          .foregroundStyle(.secondary)
      }
      SettingsSection(title: T("刷新动画")) {
        VStack(alignment: .leading, spacing: 8) {
          Text(T("刷新动画")).font(.caption).foregroundStyle(.secondary)
          LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(minimum: 105), spacing: 6), count: 5),
            spacing: 6
          ) {
            ForEach(RefreshAnimationStyle.allCases) { style in
              refreshAnimationChoice(style)
            }
          }
        }
        Text(T("刷新时只能启用一种动画；发光闪烁只作用于灵动岛下方和两侧边框。")).font(.caption).foregroundStyle(.secondary)
      }
      SettingsSection(title: T("演示预览")) {
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
    }
  }

  private func refreshAnimationChoice(_ style: RefreshAnimationStyle) -> some View {
    TileChoice(
      selection: Binding(
        get: { store.preferences.refreshAnimation },
        set: {
          store.preferences.refreshAnimation = $0
          store.previewRefreshAnimation()
        }),
      value: style
    ) {
      Text(T(style.rawValue))
    }
  }
}

// Keep geometry-driven alignment local to the two side cards so a height
// measurement does not invalidate every section and the live preview.
private struct IslandSideSettings: View {
  @ObservedObject var store: AppStore
  @State private var quotaSectionHeight: CGFloat = 0

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      SideSettingsView(
        store: store, side: $store.preferences.left, title: T("左侧"), symbol: "arrow.left",
        quotaSectionHeight: quotaSectionHeight)
      SideSettingsView(
        store: store, side: $store.preferences.right, title: T("右侧"), symbol: "arrow.right",
        quotaSectionHeight: quotaSectionHeight)
    }
    .onPreferenceChange(QuotaSectionHeightKey.self) { height in
      let rounded = ceil(height)
      if abs(rounded - quotaSectionHeight) >= 1 { quotaSectionHeight = rounded }
    }
  }
}

private struct QuotaSectionHeightKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

struct SideSettingsView: View {
  @ObservedObject var store: AppStore
  @Binding var side: SideConfiguration
  var title: String
  var symbol: String
  var quotaSectionHeight: CGFloat
  var body: some View {
    Surface {
      VStack(alignment: .leading, spacing: 16) {
        Label(title, systemImage: symbol).font(.headline)
        VStack(alignment: .leading, spacing: 8) {
          Text(T("平台")).font(.caption).foregroundStyle(.secondary)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
            ForEach(store.preferences.providersToFetch) { option in
              ProviderTileChoice(
                selection: $side.provider, value: option,
                color: store.preferences.providerColor(option)
              ) { Text(option.name) }
            }
          }
        }
        .onChange(of: side.provider) { _, _ in
          side.windowID = "primary"
          store.schedule(immediate: true)
        }
        VStack(alignment: .leading, spacing: 8) {
          Text(T("额度 / 模型")).font(.caption).foregroundStyle(.secondary)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
            ForEach(quotaOptions) { option in
              MultiTileChoice(
                selected: side.windowIDs.contains(option.id),
                disabled: side.windowIDs.count == 1 && side.windowIDs.contains(option.id),
                tint: store.preferences.providerColor(side.provider)
              ) {
                if side.windowIDs.contains(option.id) {
                  side.windowIDs.removeAll { $0 == option.id }
                } else {
                  side.windowIDs.append(option.id)
                }
              } content: {
                Text(T(option.title))
              }
            }
          }
        }
        .background {
          GeometryReader { geometry in
            Color.clear.preference(key: QuotaSectionHeightKey.self, value: geometry.size.height)
          }
        }
        .frame(minHeight: quotaSectionHeight, alignment: .top)
        Text(T("显示样式")).font(.caption).foregroundStyle(.secondary)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
          ForEach(ChartStyle.allCases) { style in
            ProviderTileChoice(
              selection: $side.style, value: style,
              color: store.preferences.providerColor(side.provider)
            ) {
              Text(T(style.title))
            }
          }
        }
        Toggle(T("显示平台图标"), isOn: $side.showIcon)
        Toggle(T("显示平台名称"), isOn: $side.showName)
        Text(T("支持多选，按选择顺序显示；至少保留一项。每项使用所选样式，缺失额度显示 —。项目较多时可横向滚动查看。"))
          .font(.system(size: 9)).foregroundStyle(.secondary)
      }.font(.system(size: 11))
    }
  }
  private var quotaOptions: [QuotaWindow] {
    var options = store.readings[side.provider]?.windows ?? []
    if options.isEmpty {
      options = [QuotaWindow(id: "primary", title: T("主要额度"), usedPercent: nil),
                 QuotaWindow(id: "secondary", title: T("次要额度"), usedPercent: nil)]
    }
    for id in side.windowIDs where !options.contains(where: { $0.id == id }) {
      options.append(QuotaWindow(id: id, title: T("%@（暂无数据）", id), usedPercent: nil))
    }
    return options
  }
}

struct ProviderDetailView: View {
  @ObservedObject var store: AppStore
  let provider: Provider

  var body: some View {
    VStack(spacing: 20) {
      Surface {
        HStack(alignment: .top, spacing: 16) {
          ProviderIcon(provider: provider, size: 34, color: store.preferences.providerColor(provider))
          VStack(alignment: .leading, spacing: 7) {
            Text(provider.name).font(.title3.weight(.semibold))
            Text(T(provider.hint)).font(.callout).foregroundStyle(.secondary)
            Text(T("直接读取此提供商已登录的本机额度数据。"))
              .font(.caption).foregroundStyle(.secondary)
          }
          Spacer()
          Toggle(T("启用"), isOn: enabled).toggleStyle(.switch)
            .disabled(provider == store.preferences.left.provider || provider == store.preferences.right.provider)
            .help(T("灵动岛左右侧正在使用的平台会保持启用"))
        }
      }
      SettingsSection(title: T("外观")) {
        HStack {
          Text(T("强调色"))
          Spacer()
          ProviderColorControl(store: store, provider: provider)
        }
      }
      SettingsSection(title: T("连接状态")) {
        if let reading = store.readings[provider] {
          LabeledContent(T("最近更新"), value: UserFacingText.dateTime(reading.updatedAt))
          LabeledContent(T("采集来源"), value: UserFacingText.source(reading.source))
          if let plan = reading.plan { LabeledContent(T("套餐"), value: plan) }
          if let account = reading.accountEmail { LabeledContent(T("账户"), value: account) }
          if let error = reading.error {
            Text(UserFacingText.value(error)).font(.caption).foregroundStyle(.orange)
          }
          if reading.windows.isEmpty && reading.error == nil {
            Text(T("暂无额度数据。请确认已在本机完成平台登录后刷新。"))
              .font(.caption).foregroundStyle(.secondary)
          }
        } else {
          Text(T("尚未采集。启用后点击工具栏的刷新按钮开始同步。"))
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      HStack {
        Spacer()
        Button(T("立即刷新")) {
          Task { await store.refreshProvider(provider) }
        }
        .disabled(store.refreshing || store.demoMode)
      }
      .font(.system(size: 12))
      HistoryView(store: store, provider: provider)
    }
  }

  private var enabled: Binding<Bool> {
    Binding(
      get: { store.preferences.enabled.contains(provider) },
      set: { value in
        if value {
          if !store.preferences.enabled.contains(provider) { store.preferences.enabled.append(provider) }
        } else {
          store.preferences.enabled.removeAll { $0 == provider }
        }
        store.schedule(immediate: true)
      })
  }
}

private struct ProviderColorControl: View {
  @ObservedObject var store: AppStore
  let provider: Provider
  @State private var draft = ""

  var body: some View {
    HStack(spacing: 8) {
      TextField(T("强调色"), text: Binding(
        get: { draft.isEmpty ? store.preferences.colorHex(for: provider) : draft },
        set: { draft = $0 }
      ))
      .textFieldStyle(.roundedBorder)
      .font(.system(size: 11, design: .monospaced))
      .frame(width: 92)
      .onSubmit(applyDraft)
      .onChange(of: draft) { _, value in
        if Self.isValidHex(value) { applyDraft() }
      }
      ColorPicker(
        T("强调色"), selection: Binding(
          get: { store.preferences.providerColor(provider) },
          set: { update(color: $0.hexString) }
        ), supportsOpacity: false
      )
      .labelsHidden()
      .frame(width: 42)
      .help(T("设置提供商强调色"))
    }
    .onAppear { draft = store.preferences.colorHex(for: provider) }
    .onChange(of: provider) { _, newProvider in
      draft = store.preferences.colorHex(for: newProvider)
    }
    .onChange(of: store.preferences.colorHex(for: provider)) { _, value in
      if !Self.isValidHex(draft) || draft.isEmpty { draft = value }
    }
  }

  private func applyDraft() {
    guard Self.isValidHex(draft) else {
      draft = store.preferences.colorHex(for: provider)
      return
    }
    update(color: draft)
  }
  private func update(color: String) {
    var preferences = store.preferences
    preferences.setColorHex(color, for: provider)
    store.preferences = preferences
    draft = preferences.colorHex(for: provider)
  }
  private static func isValidHex(_ value: String) -> Bool {
    let digits = value.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "#", with: "")
    return digits.count == 6 && digits.allSatisfy(\.isHexDigit)
  }
}

struct GeneralSettingsView: View {
  @ObservedObject var store: AppStore
  @AppStorage("interfaceLanguage") private var interfaceLanguage = InterfaceLanguage.chinese.rawValue
  @State private var loginEnabled = false
  @State private var loginStatusLoaded = false
  // Keep the untranslated key in state so changing the interface language can
  // re-render a message that was produced before the switch.
  @State private var loginMessageKey: String?
  var body: some View {
    VStack(spacing: 20) {
      Surface {
        VStack(alignment: .leading, spacing: 18) {
          Text(T("界面语言")).font(.headline)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
            ForEach(InterfaceLanguage.allCases) { language in
              TileChoice(selection: $interfaceLanguage, value: language.rawValue) {
                Text(language.title)
              }
            }
          }
          Text(T("启动与入口")).font(.headline)
          Toggle(T("登录时启动"), isOn: Binding(get: { loginEnabled }, set: setLogin)).disabled(
            !loginStatusLoaded)
          Toggle(T("启动时打开设置"), isOn: $store.preferences.openDashboardOnLaunch)
          Toggle(T("在菜单栏显示图标"), isOn: $store.preferences.showMenuBarIcon)
            .disabled(!store.preferences.showIsland)
          if let loginMessageKey {
            Text(T(loginMessageKey)).font(.caption).foregroundStyle(.orange)
          }

        }
      }
      Surface {
        VStack(alignment: .leading, spacing: 18) {
          Text(T("额度提醒与通知")).font(.headline)
          Toggle(T("低额度时改变灵动岛颜色"), isOn: $store.preferences.alerts)
          SettingsRulerControl(
            title: "橙色提醒", value: $store.preferences.warningPercent, range: 5...50,
            resetValue: 20, percentage: true)
          SettingsRulerControl(
            title: "红色提醒", value: $store.preferences.criticalPercent,
            range: 1...50, resetValue: 5, percentage: true)
          Toggle(
            T("系统通知"),
            isOn: Binding(
              get: { store.preferences.notifications },
              set: { value in
                if value {
                  store.requestNotifications()
                } else {
                  store.preferences.notifications = false
                }
              }))
          HStack {
            Toggle(T("额度重置时播放全屏彩带"), isOn: $store.preferences.celebrateReset)
            Spacer()
            Button(T("预览全屏彩带")) { AppDelegate.shared?.showConfetti() }
              .buttonStyle(.bordered)
          }
          Text(T("通知仅在进入更高告警级别时触发。过期值和演示数据不触发通知。")).font(.caption).foregroundStyle(.secondary)
        }
      }
    }.font(.system(size: 12))
      .task {
        guard !loginStatusLoaded else { return }
        // This XPC request must not run in a view initializer or on the UI thread.
        let status = await Task.detached(priority: .utility) {
          SMAppService.mainApp.status.rawValue
        }.value
        loginEnabled = status == SMAppService.Status.enabled.rawValue
        loginStatusLoaded = true
      }
  }
  private func setLogin(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      loginEnabled = SMAppService.mainApp.status == .enabled
      loginMessageKey =
        SMAppService.mainApp.status == .requiresApproval ? "请在系统设置 → 通用 → 登录项中允许启动。" : nil
    } catch {
      loginMessageKey = "启动项设置失败。请先将 App 移到「应用程序」后重试。"
      loginEnabled = SMAppService.mainApp.status == .enabled
    }
  }
}

struct AboutSettingsView: View {
  @AppStorage("interfaceLanguage") private var interfaceLanguage = InterfaceLanguage.chinese.rawValue

  var body: some View {
    VStack(spacing: 20) {
      Surface {
        VStack(alignment: .leading, spacing: 12) {
          Text("IsLandToken").font(.headline)
          Text(T("版本 %@ · macOS 14+", AppUpdater.displayVersion))
            .foregroundStyle(.secondary)
          HStack(spacing: 16) {
            Link(
              T("GitHub 项目 ↗"),
              destination: URL(string: "https://github.com/wangxinle-martin/Islandtoken")!)
          }
          .font(.system(size: 12))
          Text(T("额度优先从本机已有登录凭据读取；其他平台可通过 CodexBar 本地采集。"))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      UpdateSettingsView()
      Surface {
        VStack(alignment: .leading, spacing: 10) {
          Text(T("当前版本更新内容")).font(.headline)
          Text(T("版本 %@", AppUpdater.displayVersion)).foregroundStyle(.secondary)
          Text(CurrentReleaseNotes.text(for: interfaceLanguage))
            .font(.callout)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .font(.system(size: 12))
  }
}

private enum CurrentReleaseNotes {
  static func text(for language: String) -> String {
    let name = language == InterfaceLanguage.english.rawValue
      ? "current-release-notes-en" : "current-release-notes-zh"
    guard let url = AppResourceBundle.bundle.url(forResource: name, withExtension: "md"),
      let text = try? String(contentsOf: url, encoding: .utf8)
    else { return T("暂无当前版本更新内容。") }
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

struct TileChoice<Value: Hashable, Content: View>: View {
  @Binding var selection: Value
  let value: Value
  @ViewBuilder var content: () -> Content
  var body: some View {
    Button {
      selection = value
    } label: {
      content().choiceTileAppearance(selected: selection == value, tint: .accentColor)
    }.buttonStyle(.plain)
      .accessibilityAddTraits(selection == value ? .isSelected : [])
  }
}

/// Platform choices keep the shared option appearance while using the provider accent.
struct ProviderTileChoice<Value: Hashable, Content: View>: View {
  @Binding var selection: Value
  let value: Value
  let color: Color
  @ViewBuilder var content: () -> Content
  var body: some View {
    Button { selection = value } label: {
      content().choiceTileAppearance(selected: selection == value, tint: color)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selection == value ? .isSelected : [])
  }
}

struct MultiTileChoice<Content: View>: View {
  let selected: Bool
  var disabled = false
  var tint: Color = .accentColor
  let action: () -> Void
  @ViewBuilder var content: () -> Content
  var body: some View {
    Button(action: action) {
      content().choiceTileAppearance(selected: selected, tint: tint)
    }
    .buttonStyle(.plain)
    .disabled(disabled)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

/// One visual treatment for every selectable setting tile. Behaviour may differ
/// (single choice, provider choice, or multi-choice), but the hit area and
/// surface remain identical throughout Settings.
private extension View {
  func choiceTileAppearance(selected: Bool, tint: Color) -> some View {
    multilineTextAlignment(.center)
      // Side settings use a smaller surrounding text style for their helper
      // copy. Keep every selectable tile at the shared Settings control size.
      .font(.system(size: 12))
      .frame(maxWidth: .infinity, minHeight: 30)
      .padding(5)
      .background(
        selected ? tint.opacity(0.18) : Color.primary.opacity(0.05),
        in: RoundedRectangle(cornerRadius: 7)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 7).stroke(selected ? tint : .clear)
      )
  }
}

/// Shared card structure keeps setting categories visually consistent.
private struct SettingsSection<Content: View>: View {
  let title: String
  @ViewBuilder var content: () -> Content
  var body: some View {
    Surface {
      VStack(alignment: .leading, spacing: 18) {
        Text(title).font(.headline)
        content()
      }.font(.system(size: 12))
    }
  }
}

private struct SettingsRulerControl: View {
  let title: String
  @Binding var value: Double
  let range: ClosedRange<Double>
  var resetValue: Double = 0
  var percentage = false

  private var sliderValue: Binding<Double> {
    Binding(
      get: { (value - range.lowerBound) / (range.upperBound - range.lowerBound) },
      set: { value = (range.lowerBound + $0 * (range.upperBound - range.lowerBound)).rounded() })
  }

  var body: some View {
    HStack(spacing: 12) {
      Text(T(title)).frame(width: 76, alignment: .leading)
      VStack(spacing: 0) {
        Slider(value: sliderValue, in: 0...1)
          .accessibilityLabel(T(title))
        HStack(spacing: 0) {
          ForEach(0..<21) { index in
            Rectangle().fill(.secondary.opacity(0.4)).frame(width: 1, height: index % 5 == 0 ? 6 : 3)
            if index < 20 { Spacer(minLength: 0) }
          }
        }
        .padding(.horizontal, 8)
        .accessibilityHidden(true)
      }
      Text(percentage ? T("剩余 %d%%", Int(value)) : "\(Int(value)) pt")
        .monospacedDigit().frame(width: 90, alignment: .trailing)
      Stepper(T(title), value: $value, in: range, step: 1)
        .labelsHidden()
        .accessibilityLabel(T(title))
      Button(T("重置")) { value = min(range.upperBound, max(range.lowerBound, resetValue)) }
    }
  }

}
