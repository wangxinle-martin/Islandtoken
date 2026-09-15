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
            if let url = release.download { Link("下载新版 DMG", destination: url) }
          }
          Text("下载后打开 DMG，将应用替换到原安装位置。更新不会修改已有设置。")
            .font(.caption).foregroundStyle(.secondary)
        }
      }.frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
