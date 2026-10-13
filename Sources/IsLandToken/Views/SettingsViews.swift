import IslandCore
import ServiceManagement
import SwiftUI

struct IslandSettingsView: View {
  @ObservedObject var store: AppStore
  @State private var quotaSectionHeight: CGFloat = 0
  var body: some View {
    VStack(spacing: 22) {
      IslandPreview(store: store)
      HStack(alignment: .top, spacing: 16) {
        SideSettingsView(
          store: store, side: $store.preferences.left, title: T("左侧"), symbol: "arrow.left",
          quotaSectionHeight: quotaSectionHeight)
        SideSettingsView(
          store: store, side: $store.preferences.right, title: T("右侧"), symbol: "arrow.right",
          quotaSectionHeight: quotaSectionHeight)
      }
      .onPreferenceChange(QuotaSectionHeightKey.self) { quotaSectionHeight = $0 }
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
        HStack {
          Text(T("顶部偏移"))
          Slider(value: $store.preferences.verticalOffset, in: 0...80, step: 1)
          Text("\(Int(store.preferences.verticalOffset)) pt").monospacedDigit().frame(width: 50)
        }
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
        Toggle(T("显示剩余额度（关闭后显示已用）"), isOn: $store.preferences.remaining)
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
          Text(T("刷新动画"))
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
            ForEach(RefreshAnimationStyle.allCases) { style in
              Button {
                store.preferences.refreshAnimation = style
                store.previewRefreshAnimation()
              } label: {
                HStack(spacing: 6) {
                  Image(
                    systemName: store.preferences.refreshAnimation == style
                      ? "checkmark.circle.fill" : "circle")
                  Text(T(style.rawValue)).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(
                  store.preferences.refreshAnimation == style
                    ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06),
                  in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay(
                  RoundedRectangle(cornerRadius: 8).stroke(
                    store.preferences.refreshAnimation == style
                      ? Color.accentColor.opacity(0.65) : Color.clear, lineWidth: 1))
              }.buttonStyle(.plain)
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
              ) { Text(preset.rawValue) }
            }
          }
        }
        Text(T("橙色、红色档位直接预览对应告警颜色。")).font(.caption).foregroundStyle(.secondary)
      }
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
        Text(T("显示样式")).font(.system(size: 10)).foregroundStyle(.secondary)
        LazyVGrid(
          columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 7
        ) {
          ForEach(ChartStyle.allCases) { style in
            Button {
              side.style = style
            } label: {
              VStack(spacing: 7) {
                Image(systemName: symbol(style)).font(.system(size: 16))
                Text(T(style.title)).font(.system(size: 9))
              }.frame(maxWidth: .infinity).frame(height: 53)
                .background(
                  side.style == style
                    ? store.preferences.providerColor(side.provider).opacity(0.12) : Color.primary.opacity(0.03),
                  in: RoundedRectangle(cornerRadius: 9)
                )
                .overlay(
                  RoundedRectangle(cornerRadius: 9).stroke(
                    side.style == style ? store.preferences.providerColor(side.provider).opacity(0.55) : .clear))
            }.buttonStyle(.plain).foregroundStyle(
              side.style == style ? store.preferences.providerColor(side.provider) : .secondary)
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
  private func symbol(_ style: ChartStyle) -> String {
    switch style {
    case .ring: "circle.dashed"
    case .bar: "chart.bar.xaxis"
    case .segments: "chart.bar.fill"
    case .number: "percent"
    case .sparkline: "waveform.path"
    }
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
          LabeledContent(T("最近更新"), value: reading.updatedAt.formatted(date: .abbreviated, time: .shortened))
          LabeledContent(T("采集来源"), value: T(reading.source))
          if let plan = reading.plan { LabeledContent(T("套餐"), value: plan) }
          if let account = reading.accountEmail { LabeledContent(T("账户"), value: account) }
          if let error = reading.error { Text(T(error)).font(.caption).foregroundStyle(.orange) }
          if reading.windows.isEmpty && reading.error == nil {
            Text(T("暂无额度数据。请在 CodexBar 登录或配置此提供商后刷新。"))
              .font(.caption).foregroundStyle(.secondary)
          }
        } else {
          Text(T("尚未采集。启用后点击工具栏的刷新按钮开始同步。"))
            .font(.caption).foregroundStyle(.secondary)
        }
      }
      HStack {
        Link(T("打开提供商控制台 ↗"), destination: provider.dashboard)
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
  @State private var loginMessage: String?
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
          if let loginMessage { Text(loginMessage).font(.caption).foregroundStyle(.orange) }

        }
      }
      Surface {
        VStack(alignment: .leading, spacing: 18) {
          Text(T("额度提醒与通知")).font(.headline)
          Toggle(T("低额度时改变灵动岛颜色"), isOn: $store.preferences.alerts)
          HStack {
            Text(T("橙色提醒"))
            Slider(value: $store.preferences.warningPercent, in: 5...50, step: 1)
            Text(T("剩余 %d%%", Int(store.preferences.warningPercent))).frame(width: 78)
          }
          HStack {
            Text(T("红色提醒"))
            Slider(
              value: $store.preferences.criticalPercent, in: 1...store.preferences.warningPercent,
              step: 1)
            Text(T("剩余 %d%%", Int(store.preferences.criticalPercent))).frame(width: 78)
          }
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
      loginMessage =
        SMAppService.mainApp.status == .requiresApproval ? T("请在系统设置 → 通用 → 登录项中允许启动。") : nil
    } catch {
      loginMessage = T("启动项设置失败。请先将 App 移到「应用程序」后重试。")
      loginEnabled = SMAppService.mainApp.status == .enabled
    }
  }
}

struct AboutSettingsView: View {
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
              destination: URL(string: "https://github.com/taishanrou/Islandtoken")!)
            Link("CodexBar ↗", destination: URL(string: "https://github.com/steipete/CodexBar")!)
            Link(
              "CodexIsland ↗",
              destination: URL(string: "https://github.com/ericjypark/codex-island")!)
          }
          .font(.system(size: 12))
          Text(T("灵动岛交互参考 CodexIsland；多平台采集与图标来自 CodexBar。两个项目均以 MIT 许可发布。"))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      UpdateSettingsView()
    }
    .font(.system(size: 12))
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
      content().multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 30)
        .padding(5)
        .background(
          selection == value ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05),
          in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 7).stroke(selection == value ? Color.accentColor : .clear))
    }.buttonStyle(.plain)
      .accessibilityAddTraits(selection == value ? .isSelected : [])
  }
}

/// Platform choices use their own provider emphasis color instead of the app accent.
struct ProviderTileChoice<Value: Hashable, Content: View>: View {
  @Binding var selection: Value
  let value: Value
  let color: Color
  @ViewBuilder var content: () -> Content
  var body: some View {
    Button { selection = value } label: {
      content().multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 30)
        .padding(5)
        .foregroundStyle(selection == value ? color : .primary)
        .background(
          selection == value ? color.opacity(0.18) : Color.primary.opacity(0.05),
          in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 7).stroke(selection == value ? color : .clear)
        )
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
      content().multilineTextAlignment(.center)
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
    .buttonStyle(.plain)
    .disabled(disabled)
    .accessibilityAddTraits(selected ? .isSelected : [])
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
