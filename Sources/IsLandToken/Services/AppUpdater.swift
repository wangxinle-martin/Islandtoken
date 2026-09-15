import Combine
import Foundation
import IslandCore

@MainActor
final class AppUpdater: ObservableObject {
  static let shared = AppUpdater()
  static let repository = "taishanrou/CodexWorkspaces"
  nonisolated static let tagPrefix = "islandtoken-v"
  static var currentVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
  }
  struct Release: Decodable, Identifiable {
    let tag_name: String
    let html_url: URL
    let body: String?
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]
    var id: String { tag_name }
    var version: String { String(tag_name.dropFirst(AppUpdater.tagPrefix.count)) }
    struct Asset: Decodable {
      let name: String
      let browser_download_url: URL
    }
    var download: URL? {
      #if arch(arm64)
        let suffix = "-arm64.dmg"
      #else
        let suffix = "-x86_64.dmg"
      #endif
      return assets.first { $0.name.hasPrefix("IsLandToken-") && $0.name.hasSuffix(suffix) }?
        .browser_download_url
    }
  }
  @Published private(set) var checking = false
  @Published private(set) var available: Release?
  @Published private(set) var message = "尚未检查更新"
  func check() async {
    guard !checking else { return }
    checking = true
    defer { checking = false }
    do {
      var latest: Release?
      for page in 1...10 {
        let url = URL(
          string:
            "https://api.github.com/repos/\(Self.repository)/releases?per_page=100&page=\(page)")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (publicData, response) = try await URLSession.shared.data(for: request)
        var data = publicData
        if (response as? HTTPURLResponse)?.statusCode != 200 {
          // Private repositories use the user's own GitHub CLI authentication.
          guard
            let cli = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"].first(where: {
              FileManager.default.isExecutableFile(atPath: $0)
            })
          else { throw URLError(.userAuthenticationRequired) }
          data = try await ProcessRunner.run(
            cli,
            arguments: [
              "api",
              "repos/\(Self.repository)/releases?per_page=100&page=\(page)",
            ], timeout: 20)
        }
        let releases = try JSONDecoder().decode([Release].self, from: data)
        for release in releases
        where !release.draft && !release.prerelease && release.tag_name.hasPrefix(Self.tagPrefix) {
          guard AppVersion.components(release.version) != nil else { continue }
          if latest == nil || AppVersion.isNewer(release.version, than: latest!.version) {
            latest = release
          }
        }
        if releases.count < 100 { break }
        if page == 10 { throw URLError(.dataLengthExceedsMaximum) }
      }
      available = latest.flatMap {
        AppVersion.isNewer($0.version, than: Self.currentVersion) ? $0 : nil
      }
      message =
        available.map { "发现新版本 \($0.version)" }
        ?? (latest == nil ? "GitHub 暂无 IsLandToken 正式版本" : "当前已是最新版本")
    } catch {
      available = nil
      message = "检查失败：请检查网络；私有仓库需先在终端执行 gh auth login。"
    }
  }
}
