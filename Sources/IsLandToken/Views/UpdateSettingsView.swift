import SwiftUI

struct UpdateSettingsView: View {
  @ObservedObject private var updater = AppUpdater.shared
  @AppStorage("checkUpdatesOnLaunch") private var automatic = true
  var body: some View {
    Surface {
      VStack(alignment: .leading, spacing: 12) {
        Text("版本与更新").font(.headline)
        Text("当前版本 \(AppUpdater.currentVersion)")
        Toggle("启动时检查更新", isOn: $automatic)
        Text("运行期间每 5 分钟自动检查更新；发现新版本时提示。")
          .font(.caption).foregroundStyle(.secondary)
        HStack {
          Button(updater.checking ? "检查中…" : "检查更新") { Task { await updater.check() } }
            .disabled(updater.checking)
          Text(updater.message).font(.caption).foregroundStyle(.secondary)
        }
        if let release = updater.available {
          if let notes = release.body, !notes.isEmpty {
            Text(notes).font(.caption).textSelection(.enabled)
          }
          HStack {
            Link("查看发布说明", destination: release.html_url)
            Button(updater.installing ? "正在下载并安装…" : "下载并安装") {
              Task { await updater.downloadAndInstall(release) }
            }
            .disabled(updater.installing || release.package == nil || release.checksum == nil)
          }
          if updater.installing { ProgressView().controlSize(.small) }
          if let installMessage = updater.installMessage {
            Text(installMessage).font(.caption)
              .foregroundStyle(installMessage.hasPrefix("自动安装失败") ? .red : .secondary)
          }
          Text("点击后会自动下载、校验并替换当前应用，完成后自动重启；已有设置保持不变。")
            .font(.caption).foregroundStyle(.secondary)
        }
      }.frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

struct UpdateNoticeView: View {
  @ObservedObject private var updater = AppUpdater.shared
  let release: AppUpdater.Release
  var dismiss: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("发现新版本 \(release.version)").font(.headline)
      Text("当前版本 \(AppUpdater.currentVersion)，可自动下载、安装并重启应用。")
        .font(.callout).foregroundStyle(.secondary)
      if updater.installing { ProgressView().controlSize(.small) }
      if let installMessage = updater.installMessage {
        Text(installMessage).font(.caption)
          .foregroundStyle(installMessage.hasPrefix("自动安装失败") ? .red : .secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      HStack {
        Button("稍后", action: dismiss).disabled(updater.installing)
        Spacer()
        Link("发布说明", destination: release.html_url)
        Button(updater.installing ? "正在安装…" : "下载并安装") {
          Task { await updater.downloadAndInstall(release) }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(updater.installing || release.package == nil || release.checksum == nil)
      }
    }.padding(24).frame(width: 400)
  }
}
