import AppKit
import Combine
import Foundation
import IslandCore

@MainActor
final class AppUpdater: ObservableObject {
  static let shared = AppUpdater()
  static let repository = "taishanrou/Islandtoken"
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
      let size: Int
    }
    var package: Asset? {
      let expected = AppUpdateInstaller.assetNames(version: version).package
      return assets.first { $0.name == expected }
    }
    var checksum: Asset? {
      let expected = AppUpdateInstaller.assetNames(version: version).checksum
      return assets.first { $0.name == expected }
    }
    var download: URL? { package?.browser_download_url }
  }
  @Published private(set) var checking = false
  @Published private(set) var available: Release?
  @Published private(set) var message = "尚未检查更新"
  @Published private(set) var installing = false
  @Published private(set) var installMessage: String?
  @Published private(set) var installProgress: Double?
  @Published private(set) var canCancelInstallation = false
  @Published private(set) var cancellingInstallation = false
  private var automaticTask: Task<Void, Never>?
  private var installationTask: Task<Void, Never>?
  private var cancellationRequested = false

  private init() {
    if let failure = AppUpdateInstaller.consumeInstallationFailure() {
      let text = "上次自动安装 \(failure.version) 失败：\(failure.message)"
      message = text
      installMessage = text
    }
  }

  func startAutomaticChecks() {
    automaticTask?.cancel()
    automaticTask = Task { @MainActor [weak self] in
      if UserDefaults.standard.object(forKey: "checkUpdatesOnLaunch") as? Bool ?? true {
        await self?.check()
      }
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(300)) } catch { return }
        guard !Task.isCancelled else { return }
        await self?.check()
      }
    }
  }

  func stopAutomaticChecks() {
    automaticTask?.cancel()
    automaticTask = nil
  }

  func startDownloadAndInstall(_ release: Release) {
    guard installationTask == nil, !installing else { return }
    guard AppVersion.isNewer(release.version, than: Self.currentVersion) else {
      installMessage = "当前版本无需安装此更新。"
      return
    }
    guard let package = release.package, let checksum = release.checksum else {
      installMessage = "该版本缺少当前架构的 DMG 或 SHA-256 校验文件。"
      return
    }

    installing = true
    installProgress = 0
    canCancelInstallation = true
    cancellingInstallation = false
    cancellationRequested = false
    installMessage = "正在下载并验证 IsLandToken \(release.version)…"
    installationTask = Task { @MainActor [weak self] in
      await self?.performDownloadAndInstall(
        release, package: package, checksum: checksum)
    }
  }

  func cancelInstallation() {
    guard installing, canCancelInstallation, !cancellationRequested else { return }
    cancellationRequested = true
    cancellingInstallation = true
    canCancelInstallation = false
    installProgress = nil
    installMessage = "正在取消更新…"
    installationTask?.cancel()
  }

  private func performDownloadAndInstall(
    _ release: Release, package: Release.Asset, checksum: Release.Asset
  ) async {
    var prepared: AppUpdateInstaller.PreparedUpdate?
    defer {
      installing = false
      installProgress = nil
      canCancelInstallation = false
      cancellingInstallation = false
      cancellationRequested = false
      installationTask = nil
    }
    do {
      let update = try await AppUpdateInstaller.prepare(
        version: release.version,
        package: AppUpdateAsset(
          name: package.name, browserDownloadURL: package.browser_download_url,
          size: package.size),
        checksum: AppUpdateAsset(
          name: checksum.name, browserDownloadURL: checksum.browser_download_url,
          size: checksum.size),
        repository: Self.repository, releaseTag: release.tag_name
      ) { [weak self] progress in
        guard let self, !self.cancellationRequested else { return }
        if let fraction = progress.fraction {
          let bounded = min(1, max(0, fraction))
          self.installProgress = max(self.installProgress ?? 0, bounded)
        } else {
          self.installProgress = nil
        }
        self.installMessage = progress.message
        self.canCancelInstallation = progress.canCancel
      }
      prepared = update
      try Task.checkCancellation()
      canCancelInstallation = false
      installProgress = 1
      installMessage = "校验通过，正在退出并自动安装…"
      try await AppUpdateInstaller.launchHelper(update)
      prepared = nil
      try? await Task.sleep(for: .milliseconds(200))
      NSApp.terminate(nil)
    } catch is CancellationError {
      if let prepared { AppUpdateInstaller.discard(prepared) }
      installMessage = "更新已取消。"
    } catch {
      if let prepared { AppUpdateInstaller.discard(prepared) }
      installMessage = "自动安装失败：\(error.localizedDescription)"
    }
  }

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
      message = "检查失败：请检查网络；私有仓库需先在终端执行 gh auth login。"
    }
  }
}
