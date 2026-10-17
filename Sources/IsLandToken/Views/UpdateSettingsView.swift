import SwiftUI

struct UpdateSettingsView: View {
  @ObservedObject private var updater = AppUpdater.shared
  @AppStorage("checkUpdatesOnLaunch") private var automatic = true
  @AppStorage("interfaceLanguage") private var interfaceLanguage = InterfaceLanguage.chinese.rawValue
  var body: some View {
    Surface {
      VStack(alignment: .leading, spacing: 12) {
        Text(T("版本与更新")).font(.headline)
        Text(T("当前版本 %@", AppUpdater.displayVersion))
        Toggle(T("启动时检查更新"), isOn: $automatic)
        Text(T("运行期间每 5 分钟自动检查更新；发现新版本时提示。"))
          .font(.caption).foregroundStyle(.secondary)
        HStack {
          Button(T(updater.checking ? "检查中…" : "检查更新")) { Task { await updater.check() } }
            .disabled(updater.checking)
          Text(UserFacingText.value(updater.message)).font(.caption).foregroundStyle(.secondary)
        }
        if let release = updater.available {
          if let notes = release.body, !notes.isEmpty {
            Text(notes).font(.caption).textSelection(.enabled)
          }
          HStack {
            Link(T("查看发布说明"), destination: release.html_url)
            if updater.installing {
              Button(T(updater.cancellingInstallation ? "正在取消…" : "取消更新")) {
                updater.cancelInstallation()
              }
              .disabled(!updater.canCancelInstallation)
            } else {
              Button(T("下载并安装")) {
                updater.startDownloadAndInstall(release)
              }
              .disabled(release.package == nil || release.checksum == nil)
            }
          }
          if updater.installing {
            UpdateInstallationProgressView(updater: updater)
          } else if let installMessage = updater.installMessage {
            Text(UserFacingText.value(installMessage)).font(.caption)
              .foregroundStyle(updater.installMessageIsFailure ? .red : .secondary)
          }
          Text(T("下载阶段可取消；进入校验后会自动替换当前应用并重启，已有设置保持不变。"))
            .font(.caption).foregroundStyle(.secondary)
        }
      }.frame(maxWidth: .infinity, alignment: .leading)
    }
    .id(interfaceLanguage)
  }
}

struct UpdateNoticeView: View {
  @ObservedObject private var updater = AppUpdater.shared
  @AppStorage("interfaceLanguage") private var interfaceLanguage = InterfaceLanguage.chinese.rawValue
  let release: AppUpdater.Release
  var dismiss: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(T("发现新版本 %@", release.version)).font(.headline)
      Text(T("当前版本 %@，可自动下载、安装并重启应用。", AppUpdater.displayVersion))
        .font(.callout).foregroundStyle(.secondary)
      if updater.installing {
        UpdateInstallationProgressView(updater: updater)
      } else if let installMessage = updater.installMessage {
        Text(UserFacingText.value(installMessage)).font(.caption)
          .foregroundStyle(updater.installMessageIsFailure ? .red : .secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      HStack {
        Button(T("稍后"), action: dismiss).disabled(updater.installing)
        Spacer()
        Link(T("发布说明"), destination: release.html_url)
        if updater.installing {
          Button(T(updater.cancellingInstallation ? "正在取消…" : "取消更新")) {
            updater.cancelInstallation()
          }
          .keyboardShortcut(.cancelAction)
          .disabled(!updater.canCancelInstallation)
        } else {
          Button(T("下载并安装")) {
            updater.startDownloadAndInstall(release)
          }
          .keyboardShortcut(.defaultAction)
          .disabled(release.package == nil || release.checksum == nil)
        }
      }
    }
    .padding(24)
    .frame(width: 400)
    .id(interfaceLanguage)
  }
}

private struct UpdateInstallationProgressView: View {
  @ObservedObject var updater: AppUpdater

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Text(updater.installMessage.map { UserFacingText.value($0) } ?? T("正在准备更新…"))
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 8)
        if let progress = updater.installProgress {
          Text("\(Int(progress * 100))%")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
      if let progress = updater.installProgress {
        ProgressView(value: progress, total: 1)
          .progressViewStyle(.linear)
          .accessibilityLabel(T("更新进度"))
          .accessibilityValue("\(Int(progress * 100))%")
      } else {
        ProgressView()
          .progressViewStyle(.linear)
          .accessibilityLabel(T("更新进度"))
          .accessibilityValue(T("正在处理"))
      }
    }
  }
}
