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
          store: store, side: $store.preferences.left, title: "左侧", symbol: "arrow.left",
          quotaSectionHeight: quotaSectionHeight)
        SideSettingsView(
          store: store, side: $store.preferences.right, title: "右侧", symbol: "arrow.right",
          quotaSectionHeight: quotaSectionHeight)
      }
      .onPreferenceChange(QuotaSectionHeightKey.self) { quotaSectionHeight = $0 }
      SettingsSection(title: "位置与屏幕") {
        Toggle("显示灵动岛", isOn: $store.preferences.showIsland)
        VStack(alignment: .leading, spacing: 8) {
          Text("灵动岛显示位置").font(.caption).foregroundStyle(.secondary)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
            ForEach(IslandSideVisibility.allCases) { option in
              TileChoice(selection: $store.preferences.islandSideVisibility, value: option) {
                Text(option.title)
              }
            }
          }
        }
        Text("左侧或右侧模式将两个已选平台并排显示在刘海同一侧，另一侧宽度为零；两侧模式分别显示。").font(.caption).foregroundStyle(
          .secondary)
        Text("最小状态按所选样式显示圆环、进度条、分段、数字或趋势；鼠标移入时显示数值、百分号及已启用的图标和名称。开启系统减少动态效果时不播放弹动。").font(
          .caption
        ).foregroundStyle(.secondary)
        VStack(alignment: .leading, spacing: 8) {
          Text("显示器").font(.caption).foregroundStyle(.secondary)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
            TileChoice(selection: $store.preferences.screenID, value: "auto") {
              Text("自动 · 优先刘海屏")
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
              ) { Text("已断开 · 自动回退") }
            }
          }
        }
        HStack {
          Text("顶部偏移")
          Slider(value: $store.preferences.verticalOffset, in: 0...80, step: 1)
          Text("\(Int(store.preferences.verticalOffset)) pt").monospacedDigit().frame(width: 50)
        }
        Text("无刘海屏也可使用。若与菜单栏内容重叠，可增加顶部偏移；拔出指定显示器后会自动回退。").font(.caption).foregroundStyle(
          .secondary)
      }
      SettingsSection(title: "点击与悬停") {
        VStack(alignment: .leading, spacing: 8) {
          Text("详情显示方式").font(.caption).foregroundStyle(.secondary)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
            ForEach(DetailInteraction.allCases) { option in
              TileChoice(selection: $store.preferences.detailInteraction, value: option) {
                Text(option.title)
              }
            }
          }
        }
        Text("详情显示方式三选一。选择不显示详情时仍可悬停查看图标和百分号。菜单栏入口可在通用设置中配置。").font(.caption).foregroundStyle(
          .secondary)
      }
      SettingsSection(title: "额度与重置时间") {
        Toggle("显示剩余额度（关闭后显示已用）", isOn: $store.preferences.remaining)
        VStack(alignment: .leading, spacing: 8) {
          Text("重置时间显示方式").font(.caption).foregroundStyle(.secondary)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
            TileChoice(selection: $store.preferences.absoluteResetTime, value: false) {
              Text("倒计时")
            }
            TileChoice(selection: $store.preferences.absoluteResetTime, value: true) {
              Text("日期与时间")
            }
          }
        }
        Text("完整时间按 Mac 当前时区显示，例如 重置于 09月09日 18:30。未提供重置时间的平台仍显示原提示。").font(.caption)
          .foregroundStyle(.secondary)
      }
      SettingsSection(title: "刷新动画") {
        VStack(alignment: .leading, spacing: 8) {
          Text("刷新动画")
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
                  Text(style.rawValue).lineLimit(1)
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
        Text("刷新时只能启用一种动画；发光闪烁只作用于灵动岛下方和两侧边框。").font(.caption).foregroundStyle(.secondary)
      }
      SettingsSection(title: "演示预览") {
        Toggle("使用演示数据预览样式", isOn: Binding(get: { store.demoMode }, set: { store.setDemo($0) }))
        VStack(alignment: .leading, spacing: 8) {
          Text("演示剩余额度").font(.caption).foregroundStyle(.secondary)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
            ForEach(DemoPreset.allCases) { preset in
              TileChoice(
                selection: Binding(get: { store.demoPreset }, set: { store.setDemoPreset($0) }),
                value: preset
              ) { Text(preset.rawValue) }
            }
          }
        }
        Text("橙色、红色档位直接预览对应告警颜色。").font(.caption).foregroundStyle(.secondary)
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
          Text("平台").font(.caption).foregroundStyle(.secondary)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
            ForEach(Provider.allCases) { option in
              TileChoice(selection: $side.provider, value: option) { Text(option.name) }
            }
          }
        }
        .onChange(of: side.provider) { _, _ in
          side.windowID = "primary"
          store.schedule(immediate: true)
        }
        VStack(alignment: .leading, spacing: 8) {
          Text("额度 / 模型").font(.caption).foregroundStyle(.secondary)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
            ForEach(quotaOptions) { option in
              MultiTileChoice(
                selected: side.windowIDs.contains(option.id),
                disabled: side.windowIDs.count == 1 && side.windowIDs.contains(option.id)
              ) {
                if side.windowIDs.contains(option.id) {
                  side.windowIDs.removeAll { $0 == option.id }
                } else {
                  side.windowIDs.append(option.id)
                }
              } content: {
                Text(option.title)
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
        Text("显示样式").font(.system(size: 10)).foregroundStyle(.secondary)
        LazyVGrid(
          columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 7
        ) {
          ForEach(ChartStyle.allCases) { style in
            Button {
              side.style = style
            } label: {
              VStack(spacing: 7) {
                Image(systemName: symbol(style)).font(.system(size: 16))
                Text(style.title).font(.system(size: 9))
              }.frame(maxWidth: .infinity).frame(height: 53)
                .background(
                  side.style == style
                    ? side.provider.color.opacity(0.12) : Color.primary.opacity(0.03),
                  in: RoundedRectangle(cornerRadius: 9)
                )
                .overlay(
                  RoundedRectangle(cornerRadius: 9).stroke(
                    side.style == style ? side.provider.color.opacity(0.55) : .clear))
            }.buttonStyle(.plain).foregroundStyle(
              side.style == style ? side.provider.color : .secondary)
          }
        }
        VStack(alignment: .leading, spacing: 8) {
          Text("配色").font(.caption).foregroundStyle(.secondary)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
            ForEach(Accent.allCases) { option in
              TileChoice(selection: $side.accent, value: option) { Text(option.title) }
            }
          }
        }
        Toggle("显示平台图标", isOn: $side.showIcon)
        Toggle("显示平台名称", isOn: $side.showName)
        Text("支持多选，按选择顺序显示；至少保留一项。每项使用所选样式，缺失额度显示 —。项目较多时可横向滚动查看。")
          .font(.system(size: 9)).foregroundStyle(.secondary)
      }.font(.system(size: 11))
    }
  }
  private var quotaOptions: [QuotaWindow] {
    var options = store.readings[side.provider]?.windows ?? []
    if options.isEmpty {
      options = [QuotaWindow(id: "primary", title: "主要额度", usedPercent: nil),
                 QuotaWindow(id: "secondary", title: "次要额度", usedPercent: nil)]
    }
    for id in side.windowIDs where !options.contains(where: { $0.id == id }) {
      options.append(QuotaWindow(id: id, title: "\(id)（暂无数据）", usedPercent: nil))
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

struct ProviderSettingsView: View {
  @ObservedObject var store: AppStore
  var body: some View {
    VStack(spacing: 18) {
      SettingsSection(title: "刷新与同步") {
        VStack(alignment: .leading, spacing: 8) {
          Text("刷新间隔").font(.caption).foregroundStyle(.secondary)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
            TileChoice(selection: $store.preferences.refreshMinutes, value: 0) {
              Text("自适应（感知智能体活动）")
            }
            TileChoice(selection: $store.preferences.refreshMinutes, value: 1) { Text("1 分钟") }
            TileChoice(selection: $store.preferences.refreshMinutes, value: 5) { Text("5 分钟") }
            TileChoice(selection: $store.preferences.refreshMinutes, value: 15) { Text("15 分钟") }
            TileChoice(selection: $store.preferences.refreshMinutes, value: 30) { Text("30 分钟") }
          }
        }
        .onChange(of: store.preferences.refreshMinutes) { _, _ in store.schedule() }
        if store.preferences.refreshMinutes == 0 {
          Text("每 15 秒通过本机智能体进程 CPU 活动推断状态：近期活跃时每分钟刷新，空闲时每 5 分钟刷新；无法识别的平台按空闲频率刷新。不读取对话内容。").font(
            .caption
          ).foregroundStyle(.secondary)
        }
        Text("保守刷新，减少平台限流。电脑唤醒后会重新同步。可双击灵动岛或点击刷新按钮立即同步；采集任务依次执行。").font(.caption).foregroundStyle(
          .secondary)
      }
      Surface {
        VStack(alignment: .leading, spacing: 13) {
          HStack {
            Text("采集引擎").font(.headline)
            Spacer()
            Text(
              UsageService.resolveCLI(custom: store.preferences.cliPath) != nil
                ? "CodexBar 已就绪" : "CodexBar 未找到"
            ).font(.caption).foregroundStyle(.secondary)
          }
          VStack(alignment: .leading, spacing: 8) {
            Text("连接方式").font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
              TileChoice(selection: $store.preferences.source, value: "auto") {
                Text("自动 · 优先 CodexBar")
              }
              TileChoice(selection: $store.preferences.source, value: "codexbar") {
                Text("仅使用 CodexBar")
              }
              TileChoice(selection: $store.preferences.source, value: "direct") {
                Text("Codex / Claude 直接读取")
              }
            }
          }
          TextField("自定义 CodexBar CLI 路径（可留空）", text: $store.preferences.cliPath).textFieldStyle(
            .roundedBorder)
          Text("直接读取仅作用于 Codex / Claude；其他平台使用 CodexBar。不会向 IsLandToken 上传密码或 API Key。").font(
            .caption
          ).foregroundStyle(.secondary)
          HStack {
            Button("重新连接") {
              Task {
                await store.refresh()
                store.schedule()
              }
            }.disabled(store.refreshing || store.demoMode)
            Button("打开 CodexBar") {
              NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/CodexBar.app"))
            }
            Link("安装与平台指南 ↗", destination: URL(string: "https://github.com/steipete/CodexBar")!)
          }.font(.system(size: 11))
        }
      }
      ForEach(Provider.allCases) { provider in
        Surface {
          HStack(alignment: .top, spacing: 14) {
            ProviderIcon(provider: provider, size: 25)
            VStack(alignment: .leading, spacing: 7) {
              Text(provider.name).font(.system(size: 13, weight: .semibold))
              Text(provider.hint).font(.system(size: 11)).foregroundStyle(.secondary)
              if let error = store.readings[provider]?.error {
                Text(error).font(.system(size: 10)).foregroundStyle(.orange)
              }
              if let source = store.readings[provider]?.source {
                Text(source).font(.system(size: 9)).foregroundStyle(.tertiary)
              }
            }
            Spacer()
            Toggle(
              "启用 \(provider.name)",
              isOn: Binding(
                get: { store.preferences.providersToFetch.contains(provider) },
                set: { value in
                  if value {
                    if !store.preferences.enabled.contains(provider) {
                      store.preferences.enabled.append(provider)
                    }
                  } else {
                    store.preferences.enabled.removeAll { $0 == provider }
                  }
                  store.schedule(immediate: true)
                })
            ).labelsHidden().toggleStyle(.switch)
              .disabled(
                provider == store.preferences.left.provider
                  || provider == store.preferences.right.provider
              )
              .help("左右侧已选平台会保持启用")
          }
        }
      }
    }
  }
}

struct GeneralSettingsView: View {
  @ObservedObject var store: AppStore
  @State private var loginEnabled = false
  @State private var loginStatusLoaded = false
  @State private var loginMessage: String?
  var body: some View {
    VStack(spacing: 20) {
      UpdateSettingsView()
      Surface {
        VStack(alignment: .leading, spacing: 18) {
          Text("启动与入口").font(.headline)
          Toggle("登录时启动", isOn: Binding(get: { loginEnabled }, set: setLogin)).disabled(
            !loginStatusLoaded)
          Toggle("启动时打开控制台", isOn: $store.preferences.openDashboardOnLaunch)
          Toggle("在菜单栏显示图标", isOn: $store.preferences.showMenuBarIcon)
            .disabled(!store.preferences.showIsland)
          if let loginMessage { Text(loginMessage).font(.caption).foregroundStyle(.orange) }

        }
      }
      Surface {
        VStack(alignment: .leading, spacing: 18) {
          Text("额度提醒与通知").font(.headline)
          Toggle("低额度时改变灵动岛颜色", isOn: $store.preferences.alerts)
          HStack {
            Text("橙色提醒")
            Slider(value: $store.preferences.warningPercent, in: 5...50, step: 1)
            Text("剩余 \(Int(store.preferences.warningPercent))%").frame(width: 78)
          }
          HStack {
            Text("红色提醒")
            Slider(
              value: $store.preferences.criticalPercent, in: 1...store.preferences.warningPercent,
              step: 1)
            Text("剩余 \(Int(store.preferences.criticalPercent))%").frame(width: 78)
          }
          Toggle(
            "系统通知",
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
            Toggle("额度重置时播放全屏彩带", isOn: $store.preferences.celebrateReset)
            Spacer()
            Button("预览全屏彩带") { AppDelegate.shared?.showConfetti() }
              .buttonStyle(.bordered)
          }
          Text("通知仅在进入更高告警级别时触发。过期值和演示数据不触发通知。").font(.caption).foregroundStyle(.secondary)
        }
      }
      Surface {
        VStack(alignment: .leading, spacing: 15) {
          Text("关于 IsLandToken").font(.headline)
          Text(
            "IsLandToken \(AppUpdater.currentVersion) · macOS 14+\n灵动岛交互参考 CodexIsland；多平台采集与图标来自 CodexBar。两个项目均以 MIT 许可发布。"
          ).font(.caption).foregroundStyle(.secondary)
          HStack {
            Link("CodexBar ↗", destination: URL(string: "https://github.com/steipete/CodexBar")!)
            Link(
              "CodexIsland ↗",
              destination: URL(string: "https://github.com/ericjypark/codex-island")!)
            Spacer()
            Button("退出 IsLandToken") { NSApp.terminate(nil) }
          }.font(.system(size: 11))
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
        SMAppService.mainApp.status == .requiresApproval ? "请在系统设置 → 通用 → 登录项中允许启动。" : nil
    } catch {
      loginMessage = "启动项设置失败。请先将 App 移到「应用程序」后重试。"
      loginEnabled = SMAppService.mainApp.status == .enabled
    }
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

struct MultiTileChoice<Content: View>: View {
  let selected: Bool
  var disabled = false
  let action: () -> Void
  @ViewBuilder var content: () -> Content
  var body: some View {
    Button(action: action) {
      content().multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 30)
        .padding(5)
        .background(
          selected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05),
          in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 7).stroke(selected ? Color.accentColor : .clear)
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
