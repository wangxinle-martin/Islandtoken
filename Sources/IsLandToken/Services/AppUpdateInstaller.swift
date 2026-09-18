import CryptoKit
import Darwin
import Foundation
import IslandCore

struct AppUpdateAsset: Sendable {
  let name: String
  let browserDownloadURL: URL
  let size: Int
}

struct AppUpdatePreparationProgress: Sendable {
  let fraction: Double?
  let message: String
  let canCancel: Bool
}

enum AppUpdateInstaller {
  static let bundleIdentifier = "com.wangxinle.IsLandToken"
  static let helperFlag = "--apply-islandtoken-update-v1"
  static let acknowledgementFlag = "--acknowledge-islandtoken-update"
  typealias ProgressHandler = @MainActor @Sendable (AppUpdatePreparationProgress) -> Void

  struct PreparedUpdate: Sendable {
    let version: String
    let targetApplication: URL
    let stagedApplication: URL
    let helperExecutable: URL
    let readyFile: URL
    let acknowledgementFile: URL
    let workingDirectory: URL
  }

  struct InstallationResult: Codable, Sendable {
    let version: String
    let message: String
    let createdAt: Date
  }

  private struct PendingTransaction: Codable, Sendable {
    let version: String
    let targetApplicationPath: String
    let stagedApplicationPath: String
    let workingDirectoryPath: String
    let createdAt: Date

    var targetApplication: URL {
      URL(fileURLWithPath: targetApplicationPath).resolvingSymlinksInPath()
    }
    var stagedApplication: URL {
      URL(fileURLWithPath: stagedApplicationPath).resolvingSymlinksInPath()
    }
    var workingDirectory: URL {
      URL(fileURLWithPath: workingDirectoryPath).resolvingSymlinksInPath()
    }
  }

  private static var recoveredTransaction: PendingTransaction?

  static var architectureName: String {
    #if arch(arm64)
      return "arm64"
    #else
      return "x86_64"
    #endif
  }

  static func assetNames(version: String, architecture: String? = nil) -> (
    package: String, checksum: String
  ) {
    let package = "IsLandToken-\(version)-\(architecture ?? architectureName).dmg"
    return (package, package + ".sha256")
  }

  static func prepare(
    version: String, package: AppUpdateAsset, checksum: AppUpdateAsset,
    repository: String, releaseTag: String, progress: ProgressHandler? = nil
  ) async throws -> PreparedUpdate {
    guard AppVersion.components(version) != nil else {
      throw UpdateInstallationError.message("新版本号格式无效。")
    }
    let expectedNames = assetNames(version: version)
    guard package.name == expectedNames.package, checksum.name == expectedNames.checksum else {
      throw UpdateInstallationError.message("更新包名称与版本或处理器架构不匹配。")
    }
    guard let currentExecutable = Bundle.main.executableURL else {
      throw UpdateInstallationError.message("无法定位当前应用程序。")
    }
    let targetApplication = Bundle.main.bundleURL.resolvingSymlinksInPath()
    guard targetApplication.pathExtension == "app",
      Bundle(url: targetApplication)?.bundleIdentifier == bundleIdentifier
    else {
      throw UpdateInstallationError.message("请先将 IsLandToken 放入应用程序文件夹后再自动更新。")
    }
    let parent = targetApplication.deletingLastPathComponent()
    guard FileManager.default.isWritableFile(atPath: parent.path) else {
      throw UpdateInstallationError.message("当前安装位置不可写，无法自动替换应用。")
    }

    let workingDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "islandtoken-update-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: workingDirectory, withIntermediateDirectories: false,
      attributes: [.posixPermissions: 0o700])
    var stagedApplication: URL?
    do {
      let packageURL = workingDirectory.appendingPathComponent(package.name)
      let checksumURL = workingDirectory.appendingPathComponent(checksum.name)
      await progress?(
        .init(fraction: 0, message: "正在下载 IsLandToken \(version)…", canCancel: true))
      try Task.checkCancellation()
      try await downloadAssets(
        package: package, checksum: checksum, packageURL: packageURL,
        checksumURL: checksumURL, repository: repository, releaseTag: releaseTag,
        progress: progress)
      try Task.checkCancellation()
      await progress?(.init(fraction: nil, message: "正在校验更新包…", canCancel: false))
      try Task.checkCancellation()

      let staged = parent.appendingPathComponent(
        ".IsLandToken-update-\(UUID().uuidString).app", isDirectory: true)
      stagedApplication = staged
      try await Task.detached(priority: .utility) {
        try verifyAndStage(
          packageURL: packageURL, checksumURL: checksumURL,
          expectedVersion: version, stagedApplication: staged,
          workingDirectory: workingDirectory)
      }.value
      try Task.checkCancellation()
      await progress?(.init(fraction: nil, message: "正在准备安装…", canCancel: false))
      try Task.checkCancellation()

      let helperExecutable = workingDirectory.appendingPathComponent("IsLandTokenUpdater")
      try FileManager.default.copyItem(at: currentExecutable, to: helperExecutable)
      guard chmod(helperExecutable.path, mode_t(S_IRUSR | S_IWUSR | S_IXUSR)) == 0 else {
        throw UpdateInstallationError.posix("无法设置更新辅助程序权限")
      }
      return PreparedUpdate(
        version: version,
        targetApplication: targetApplication,
        stagedApplication: staged,
        helperExecutable: helperExecutable,
        readyFile: workingDirectory.appendingPathComponent("helper-ready"),
        acknowledgementFile: workingDirectory.appendingPathComponent("launch-ack"),
        workingDirectory: workingDirectory)
    } catch {
      if let stagedApplication { try? FileManager.default.removeItem(at: stagedApplication) }
      try? FileManager.default.removeItem(at: workingDirectory)
      throw error
    }
  }

  static func launchHelper(_ update: PreparedUpdate) async throws {
    try? FileManager.default.removeItem(at: update.readyFile)
    try? FileManager.default.removeItem(at: update.acknowledgementFile)
    let log = update.workingDirectory.appendingPathComponent("helper.log")
    FileManager.default.createFile(
      atPath: log.path, contents: nil, attributes: [.posixPermissions: 0o600])
    let logHandle = try FileHandle(forWritingTo: log)
    let process = Process()
    process.executableURL = update.helperExecutable
    process.arguments = [
      helperFlag,
      update.stagedApplication.path,
      update.targetApplication.path,
      String(ProcessInfo.processInfo.processIdentifier),
      update.version,
      update.readyFile.path,
      update.acknowledgementFile.path,
      update.workingDirectory.path,
    ]
    process.standardOutput = logHandle
    process.standardError = logHandle
    process.standardInput = FileHandle.nullDevice
    try process.run()

    for _ in 0..<200 {
      if FileManager.default.fileExists(atPath: update.readyFile.path) {
        try? logHandle.close()
        return
      }
      guard process.isRunning else {
        try? logHandle.close()
        let detail = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        throw UpdateInstallationError.message(
          detail.isEmpty ? "更新辅助程序未能启动。" : "更新辅助程序未能启动：\(detail)")
      }
      try await Task.sleep(for: .milliseconds(50))
    }
    if process.isRunning { stop(process) }
    try? logHandle.close()
    throw UpdateInstallationError.message("等待更新辅助程序就绪超时。")
  }

  static func discard(_ update: PreparedUpdate) {
    try? FileManager.default.removeItem(at: update.stagedApplication)
    try? FileManager.default.removeItem(at: update.workingDirectory)
  }

  static func runHelperIfRequested(arguments: [String] = CommandLine.arguments) -> Bool {
    guard let flagIndex = arguments.firstIndex(of: helperFlag) else { return false }
    let values = Array(arguments.dropFirst(flagIndex + 1))
    guard values.count == 7, let parentPID = pid_t(values[2]), parentPID > 0 else {
      NSLog("IsLandToken updater received invalid arguments.")
      return true
    }
    let invocation = HelperInvocation(
      helperExecutable: URL(fileURLWithPath: arguments[0]).resolvingSymlinksInPath(),
      stagedApplication: URL(fileURLWithPath: values[0]).resolvingSymlinksInPath(),
      targetApplication: URL(fileURLWithPath: values[1]).resolvingSymlinksInPath(),
      parentPID: parentPID,
      version: values[3],
      readyFile: URL(fileURLWithPath: values[4]).resolvingSymlinksInPath(),
      acknowledgementFile: URL(fileURLWithPath: values[5]).resolvingSymlinksInPath(),
      workingDirectory: URL(fileURLWithPath: values[6]).resolvingSymlinksInPath())
    do {
      try applyUpdate(invocation)
    } catch {
      NSLog("IsLandToken updater failed: %@", error.localizedDescription)
    }
    return true
  }

  /// Returns true whenever this launch contains the updater acknowledgement flag.
  /// A rejected or failed acknowledgement still owns this launch: the helper must
  /// retain the rollback bundle and decide whether to commit or roll back.
  @discardableResult
  static func handleLaunchAcknowledgementIfRequested(
    arguments: [String] = CommandLine.arguments
  ) -> Bool {
    guard arguments.contains(acknowledgementFlag) else { return false }
    guard let acknowledgement = validatedAcknowledgementURL(arguments: arguments) else {
      NSLog("IsLandToken rejected an invalid update launch acknowledgement.")
      return true
    }
    do {
      try Data("ready\n".utf8).write(to: acknowledgement, options: .atomic)
    } catch {
      NSLog("IsLandToken could not acknowledge the updated launch: %@", error.localizedDescription)
    }
    return true
  }

  static func isValidatedUpdateRelaunch(
    arguments: [String] = CommandLine.arguments
  ) -> Bool {
    validatedAcknowledgementURL(arguments: arguments) != nil
  }

  static func validatedUpdateHelperExecutable(
    arguments: [String] = CommandLine.arguments
  ) -> URL? {
    validatedAcknowledgementURL(arguments: arguments)?
      .deletingLastPathComponent()
      .appendingPathComponent("IsLandTokenUpdater")
      .resolvingSymlinksInPath()
  }

  static func consumeInstallationFailure() -> InstallationResult? {
    guard let url = installationResultURL(),
      let data = try? Data(contentsOf: url),
      let result = try? JSONDecoder().decode(InstallationResult.self, from: data)
    else { return nil }
    try? FileManager.default.removeItem(at: url)
    return result
  }

  /// Resolve an update interrupted by a reboot or a terminated helper. No bundle is swapped here:
  /// the current executable proves which side of the atomic transaction is active.
  static func recoverInterruptedTransactionIfNeeded() {
    guard let transaction = readPendingTransaction(),
      validateTransactionPaths(transaction),
      Bundle.main.bundleURL.resolvingSymlinksInPath() == transaction.targetApplication,
      let currentBundle = Bundle(url: transaction.targetApplication),
      currentBundle.bundleIdentifier == bundleIdentifier,
      let currentVersion = currentBundle.object(
        forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    else { return }

    if currentVersion == transaction.version {
      if FileManager.default.fileExists(atPath: transaction.stagedApplication.path) {
        guard Bundle(url: transaction.stagedApplication)?.bundleIdentifier == bundleIdentifier
        else { return }
        recoveredTransaction = transaction
      } else {
        removePendingTransaction()
        try? FileManager.default.removeItem(at: transaction.workingDirectory)
      }
      return
    }

    if !FileManager.default.fileExists(atPath: transaction.stagedApplication.path) {
      removePendingTransaction()
      try? FileManager.default.removeItem(at: transaction.workingDirectory)
      return
    }
    guard let stagedBundle = Bundle(url: transaction.stagedApplication),
      stagedBundle.bundleIdentifier == bundleIdentifier,
      stagedBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        == transaction.version
    else { return }
    // The swap never happened (or was already rolled back), so the current app is still safe.
    try? FileManager.default.removeItem(at: transaction.stagedApplication)
    try? FileManager.default.removeItem(at: transaction.workingDirectory)
    removePendingTransaction()
  }

  static func commitRecoveredTransactionIfNeeded() {
    guard let transaction = recoveredTransaction,
      validateTransactionPaths(transaction),
      Bundle.main.bundleURL.resolvingSymlinksInPath() == transaction.targetApplication,
      Bundle(url: transaction.targetApplication)?.object(
        forInfoDictionaryKey: "CFBundleShortVersionString") as? String == transaction.version
    else { return }
    try? FileManager.default.removeItem(at: transaction.stagedApplication)
    try? FileManager.default.removeItem(at: transaction.workingDirectory)
    removePendingTransaction()
    recoveredTransaction = nil
  }

  static func expectedChecksum(in sidecar: String, packageName: String) -> String? {
    guard let line = sidecar.split(whereSeparator: { $0.isNewline }).first else { return nil }
    let fields = line.split(whereSeparator: { $0.isWhitespace })
    guard fields.count >= 2 else { return nil }
    let digest = String(fields[0]).lowercased()
    let recordedName = String(fields[fields.count - 1]).trimmingCharacters(
      in: CharacterSet(charactersIn: "*"))
    guard digest.count == 64, digest.allSatisfy({ $0.isHexDigit }), recordedName == packageName
    else { return nil }
    return digest
  }

  static func atomicSwap(_ first: URL, _ second: URL) throws {
    let result = first.withUnsafeFileSystemRepresentation { firstPath in
      second.withUnsafeFileSystemRepresentation { secondPath in
        guard let firstPath, let secondPath else { return Int32(-1) }
        return renamex_np(firstPath, secondPath, UInt32(RENAME_SWAP))
      }
    }
    guard result == 0 else { throw UpdateInstallationError.posix("无法原子替换应用") }
  }

  private struct HelperInvocation {
    let helperExecutable: URL
    let stagedApplication: URL
    let targetApplication: URL
    let parentPID: pid_t
    let version: String
    let readyFile: URL
    let acknowledgementFile: URL
    let workingDirectory: URL
  }

  private static func downloadAssets(
    package: AppUpdateAsset, checksum: AppUpdateAsset, packageURL: URL,
    checksumURL: URL, repository: String, releaseTag: String,
    progress: ProgressHandler?
  ) async throws {
    let totalBytes = max(1, package.size + checksum.size)
    do {
      try await download(
        asset: package, to: packageURL, completedBytes: 0, totalBytes: totalBytes,
        progress: progress)
      try await download(
        asset: checksum, to: checksumURL, completedBytes: package.size,
        totalBytes: totalBytes, progress: progress)
      try validateSize(of: packageURL, expected: package.size)
      try validateSize(of: checksumURL, expected: checksum.size)
      return
    } catch is CancellationError {
      try? FileManager.default.removeItem(at: packageURL)
      try? FileManager.default.removeItem(at: checksumURL)
      throw CancellationError()
    } catch {
      try? FileManager.default.removeItem(at: packageURL)
      try? FileManager.default.removeItem(at: checksumURL)
    }

    try Task.checkCancellation()
    guard let gh = githubCLI() else {
      throw UpdateInstallationError.message(
        "无法下载更新；私有仓库请先安装 GitHub CLI 并执行 gh auth login。")
    }
    do {
      await progress?(
        .init(fraction: nil, message: "正在通过 GitHub CLI 下载…", canCancel: true))
      _ = try await runCancellableProcess(
        gh,
        arguments: [
          "release", "download", releaseTag,
          "--repo", repository,
          "--pattern", package.name,
          "--pattern", checksum.name,
          "--dir", packageURL.deletingLastPathComponent().path,
          "--clobber",
        ], timeout: 300)
      try Task.checkCancellation()
      try validateSize(of: packageURL, expected: package.size)
      try validateSize(of: checksumURL, expected: checksum.size)
    } catch is CancellationError {
      try? FileManager.default.removeItem(at: packageURL)
      try? FileManager.default.removeItem(at: checksumURL)
      throw CancellationError()
    } catch {
      throw UpdateInstallationError.message(
        "自动下载失败；请检查网络以及 gh auth status。\(error.localizedDescription)")
    }
  }

  static func downloadFraction(completedBytes: Int64, totalBytes: Int64) -> Double {
    guard totalBytes > 0 else { return 0 }
    return min(1, max(0, Double(completedBytes) / Double(totalBytes)))
  }

  /// Internal so the pre-cancel race can be exercised without preparing a real app update.
  static func download(
    asset: AppUpdateAsset, to destination: URL, completedBytes: Int,
    totalBytes: Int, progress: ProgressHandler?
  ) async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 60
    configuration.timeoutIntervalForResource = 300
    configuration.waitsForConnectivity = true
    let session = URLSession(configuration: configuration)
    let taskBox = DownloadTaskBox()
    defer {
      taskBox.finish()
      session.finishTasksAndInvalidate()
    }
    var request = URLRequest(url: asset.browserDownloadURL)
    request.timeoutInterval = 300
    request.setValue("IsLandToken-Updater", forHTTPHeaderField: "User-Agent")
    do {
      try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation {
          (continuation: CheckedContinuation<Void, Error>) in
          let task = session.downloadTask(with: request) { temporaryURL, response, error in
            taskBox.markDownloadFinished()
            if let error {
              if (error as? URLError)?.code == .cancelled {
                continuation.resume(throwing: CancellationError())
              } else {
                continuation.resume(throwing: error)
              }
              return
            }
            guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode), let temporaryURL
            else {
              continuation.resume(
                throwing: UpdateInstallationError.message("GitHub 返回了无效的下载响应。"))
              return
            }
            do {
              try? FileManager.default.removeItem(at: destination)
              try FileManager.default.moveItem(at: temporaryURL, to: destination)
              continuation.resume()
            } catch {
              continuation.resume(throwing: error)
            }
          }
          taskBox.store(task)
          if let progress {
            let poller = Task.detached(priority: .utility) {
              while !Task.isCancelled {
                let received = max(0, Int(task.countOfBytesReceived))
                let bytes = min(totalBytes, completedBytes + received)
                let fraction = downloadFraction(
                  completedBytes: Int64(bytes), totalBytes: Int64(totalBytes))
                await progress(
                  .init(
                    fraction: fraction, message: "正在下载… \(Int(fraction * 100))%",
                    canCancel: true))
                if task.state == .completed || task.state == .canceling { return }
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
              }
            }
            taskBox.store(poller: poller)
          }
          task.resume()
        }
      } onCancel: {
        // Keep the session valid until the continuation finishes. The box also covers
        // cancellation that wins the race before the URLSession task is stored.
        taskBox.cancel()
      }
    } catch {
      let progressTask = taskBox.takeProgressTask()
      progressTask?.cancel()
      await progressTask?.value
      throw error
    }
    let progressTask = taskBox.takeProgressTask()
    progressTask?.cancel()
    await progressTask?.value
    try Task.checkCancellation()
    let completed = min(totalBytes, completedBytes + asset.size)
    let finalFraction = downloadFraction(
      completedBytes: Int64(completed), totalBytes: Int64(totalBytes))
    await progress?(
      .init(
        fraction: finalFraction,
        message: "正在下载… \(Int(finalFraction * 100))%",
        canCancel: true))
    try Task.checkCancellation()
  }

  private static func validateSize(of file: URL, expected: Int) throws {
    let actual = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1
    guard expected > 0, actual == expected else {
      throw UpdateInstallationError.message("下载文件大小与 GitHub 发布信息不一致。")
    }
  }

  private static func verifyAndStage(
    packageURL: URL, checksumURL: URL, expectedVersion: String,
    stagedApplication: URL, workingDirectory: URL
  ) throws {
    let sidecar = try String(contentsOf: checksumURL, encoding: .utf8)
    guard let expected = expectedChecksum(in: sidecar, packageName: packageURL.lastPathComponent)
    else { throw UpdateInstallationError.message("更新包校验文件格式无效。") }
    let data = try Data(contentsOf: packageURL, options: .mappedIfSafe)
    let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    guard actual == expected else {
      throw UpdateInstallationError.message("更新包 SHA-256 校验失败，已停止安装。")
    }

    _ = try runProcess("/usr/bin/hdiutil", arguments: ["verify", packageURL.path], timeout: 120)
    let mountPoint = workingDirectory.appendingPathComponent("mounted", isDirectory: true)
    try FileManager.default.createDirectory(
      at: mountPoint, withIntermediateDirectories: false,
      attributes: [.posixPermissions: 0o700])
    var mounted = false
    do {
      _ = try runProcess(
        "/usr/bin/hdiutil",
        arguments: [
          "attach", packageURL.path, "-readonly", "-nobrowse", "-noautoopen",
          "-mountpoint", mountPoint.path,
        ], timeout: 120)
      mounted = true
      let candidate = mountPoint.appendingPathComponent("IsLandToken.app", isDirectory: true)
      try validateApplication(candidate, expectedVersion: expectedVersion)
      _ = try runProcess(
        "/usr/bin/ditto", arguments: [candidate.path, stagedApplication.path], timeout: 180)
      try validateApplication(stagedApplication, expectedVersion: expectedVersion)
      _ = try runProcess(
        "/usr/bin/hdiutil", arguments: ["detach", mountPoint.path], timeout: 60)
      mounted = false
    } catch {
      if mounted {
        _ = try? runProcess(
          "/usr/bin/hdiutil", arguments: ["detach", mountPoint.path, "-force"], timeout: 60)
      }
      throw error
    }
  }

  private static func validateApplication(_ application: URL, expectedVersion: String) throws {
    let resourceValues = try application.resourceValues(
      forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard resourceValues.isDirectory == true, resourceValues.isSymbolicLink != true,
      let bundle = Bundle(url: application), bundle.bundleIdentifier == bundleIdentifier,
      bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        == expectedVersion,
      let executable = bundle.executableURL
    else { throw UpdateInstallationError.message("更新包中的应用身份或版本不正确。") }
    _ = try runProcess(
      "/usr/bin/codesign", arguments: ["--verify", "--deep", "--strict", application.path],
      timeout: 60)
    let architectures = try runProcess(
      "/usr/bin/lipo", arguments: ["-archs", executable.path], timeout: 30)
    let text = String(decoding: architectures, as: UTF8.self)
    guard text.split(whereSeparator: { $0.isWhitespace }).contains(Substring(architectureName))
    else {
      throw UpdateInstallationError.message("更新包不支持当前 Mac 的处理器架构。")
    }
  }

  private static func applyUpdate(_ invocation: HelperInvocation) throws {
    guard validateHelperInvocation(invocation),
      Bundle(url: invocation.targetApplication)?.bundleIdentifier == bundleIdentifier,
      let stagedBundle = Bundle(url: invocation.stagedApplication),
      stagedBundle.bundleIdentifier == bundleIdentifier,
      stagedBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        == invocation.version
    else { throw UpdateInstallationError.message("更新辅助程序拒绝了无效的应用路径。") }

    try Data("ready\n".utf8).write(to: invocation.readyFile, options: .atomic)
    guard waitForExit(pid: invocation.parentPID, timeout: 30) else {
      let error = UpdateInstallationError.message("旧版本未能按时退出，更新尚未安装。")
      writeInstallationFailure(version: invocation.version, error: error)
      try? FileManager.default.removeItem(at: invocation.stagedApplication)
      try? launchUsingOpen(invocation.targetApplication)
      try? FileManager.default.removeItem(at: invocation.workingDirectory)
      return
    }

    let transaction = PendingTransaction(
      version: invocation.version,
      targetApplicationPath: invocation.targetApplication.path,
      stagedApplicationPath: invocation.stagedApplication.path,
      workingDirectoryPath: invocation.workingDirectory.path,
      createdAt: Date())
    do {
      try writePendingTransaction(transaction)
    } catch {
      writeInstallationFailure(version: invocation.version, error: error)
      try? FileManager.default.removeItem(at: invocation.stagedApplication)
      try? launchUsingOpen(invocation.targetApplication)
      try? FileManager.default.removeItem(at: invocation.workingDirectory)
      return
    }

    do {
      try atomicSwap(invocation.targetApplication, invocation.stagedApplication)
    } catch {
      writeInstallationFailure(version: invocation.version, error: error)
      try? FileManager.default.removeItem(at: invocation.stagedApplication)
      try? launchUsingOpen(invocation.targetApplication)
      removePendingTransaction()
      try? FileManager.default.removeItem(at: invocation.workingDirectory)
      return
    }

    var launched: Process?
    do {
      try? FileManager.default.removeItem(at: invocation.acknowledgementFile)
      let executable = try applicationExecutable(invocation.targetApplication)
      let process = Process()
      process.executableURL = executable
      process.arguments = [acknowledgementFlag, invocation.acknowledgementFile.path]
      process.standardOutput = FileHandle.nullDevice
      process.standardError = FileHandle.nullDevice
      process.standardInput = FileHandle.nullDevice
      try process.run()
      launched = process
      guard
        waitForAcknowledgement(
          invocation.acknowledgementFile, process: process, timeout: 30)
      else { throw UpdateInstallationError.message("新版启动验证失败。") }
      try? FileManager.default.removeItem(at: invocation.stagedApplication)
      removePendingTransaction()
      try? FileManager.default.removeItem(at: invocation.workingDirectory)
    } catch {
      if let launched { stop(launched) }
      do {
        try atomicSwap(invocation.targetApplication, invocation.stagedApplication)
      } catch let rollbackError {
        writeInstallationFailure(
          version: invocation.version,
          error: UpdateInstallationError.message(
            "新版启动失败，且自动回滚失败。旧版仍保留在 \(invocation.stagedApplication.path)。"
              + " \(rollbackError.localizedDescription)"))
        try? launchUsingOpen(invocation.stagedApplication)
        return
      }

      try? FileManager.default.removeItem(at: invocation.stagedApplication)
      writeInstallationFailure(version: invocation.version, error: error)
      removePendingTransaction()
      do {
        try launchUsingOpen(invocation.targetApplication)
      } catch let relaunchError {
        writeInstallationFailure(
          version: invocation.version,
          error: UpdateInstallationError.message(
            "新版启动失败，旧版已恢复，但自动重启失败。请手动打开 "
              + "\(invocation.targetApplication.path)。 \(relaunchError.localizedDescription)"))
      }
      try? FileManager.default.removeItem(at: invocation.workingDirectory)
    }
  }

  private static func waitForExit(pid: pid_t, timeout: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      errno = 0
      if kill(pid, 0) != 0, errno == ESRCH { return true }
      usleep(100_000)
    }
    return false
  }

  private static func waitForAcknowledgement(
    _ acknowledgement: URL, process: Process, timeout: TimeInterval
  ) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if FileManager.default.fileExists(atPath: acknowledgement.path) { return true }
      if !process.isRunning { return false }
      usleep(100_000)
    }
    return false
  }

  private static func stop(_ process: Process) {
    guard process.isRunning else { return }
    process.terminate()
    let deadline = Date().addingTimeInterval(5)
    while process.isRunning, Date() < deadline { usleep(100_000) }
    if process.isRunning {
      kill(process.processIdentifier, SIGKILL)
      process.waitUntilExit()
    }
  }

  private static func applicationExecutable(_ application: URL) throws -> URL {
    guard let executable = Bundle(url: application)?.executableURL else {
      throw UpdateInstallationError.message("安装后的应用缺少可执行程序。")
    }
    return executable
  }

  private static func launchUsingOpen(_ application: URL) throws {
    _ = try runProcess(
      "/usr/bin/open", arguments: ["-n", application.path], timeout: 30)
  }

  private static func githubCLI() -> String? {
    ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"].first {
      FileManager.default.isExecutableFile(atPath: $0)
    }
  }

  private static func validateHelperInvocation(_ invocation: HelperInvocation) -> Bool {
    guard validateWorkingDirectory(invocation.workingDirectory, requireExisting: true),
      invocation.helperExecutable.deletingLastPathComponent() == invocation.workingDirectory,
      invocation.helperExecutable.lastPathComponent == "IsLandTokenUpdater",
      invocation.readyFile.deletingLastPathComponent() == invocation.workingDirectory,
      invocation.acknowledgementFile.deletingLastPathComponent()
        == invocation.workingDirectory,
      invocation.readyFile.lastPathComponent == "helper-ready",
      invocation.acknowledgementFile.lastPathComponent == "launch-ack",
      invocation.targetApplication.deletingLastPathComponent()
        == invocation.stagedApplication.deletingLastPathComponent(),
      invocation.targetApplication.pathExtension == "app",
      invocation.stagedApplication.pathExtension == "app",
      invocation.stagedApplication.lastPathComponent.hasPrefix(".IsLandToken-update-")
    else { return false }
    return true
  }

  private static func validateTransactionPaths(_ transaction: PendingTransaction) -> Bool {
    guard validateWorkingDirectory(transaction.workingDirectory, requireExisting: false),
      transaction.targetApplication.deletingLastPathComponent()
        == transaction.stagedApplication.deletingLastPathComponent(),
      transaction.targetApplication.pathExtension == "app",
      transaction.stagedApplication.pathExtension == "app",
      transaction.stagedApplication.lastPathComponent.hasPrefix(".IsLandToken-update-")
    else { return false }
    return true
  }

  private static func validateWorkingDirectory(
    _ directory: URL, requireExisting: Bool
  ) -> Bool {
    let normalized = directory.resolvingSymlinksInPath()
    let temporaryRoot = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
    guard normalized.deletingLastPathComponent() == temporaryRoot,
      normalized.lastPathComponent.hasPrefix("islandtoken-update-")
    else { return false }
    guard FileManager.default.fileExists(atPath: normalized.path) else {
      return !requireExisting
    }
    guard
      let attributes = try? FileManager.default.attributesOfItem(atPath: normalized.path),
      attributes[.type] as? FileAttributeType == .typeDirectory,
      let owner = attributes[.ownerAccountID] as? NSNumber,
      owner.uint32Value == geteuid(),
      let permissions = attributes[.posixPermissions] as? NSNumber,
      permissions.intValue & 0o777 == 0o700
    else { return false }
    return true
  }

  private static func validatedAcknowledgementURL(arguments: [String]) -> URL? {
    guard let index = arguments.firstIndex(of: acknowledgementFlag),
      arguments.count == index + 2
    else { return nil }
    let acknowledgement = URL(fileURLWithPath: arguments[index + 1])
      .resolvingSymlinksInPath()
    guard acknowledgement.lastPathComponent == "launch-ack",
      validateWorkingDirectory(
        acknowledgement.deletingLastPathComponent(), requireExisting: true),
      let transaction = readPendingTransaction(), validateTransactionPaths(transaction),
      transaction.workingDirectory == acknowledgement.deletingLastPathComponent(),
      transaction.targetApplication == Bundle.main.bundleURL.resolvingSymlinksInPath(),
      Bundle(url: transaction.targetApplication)?.object(
        forInfoDictionaryKey: "CFBundleShortVersionString") as? String == transaction.version
    else { return nil }
    return acknowledgement
  }

  private static func pendingTransactionURL() -> URL? {
    applicationSupportDirectory()?.appendingPathComponent("pending-update.json")
  }

  private static func writePendingTransaction(_ transaction: PendingTransaction) throws {
    guard let url = pendingTransactionURL() else {
      throw UpdateInstallationError.message("无法保存更新事务状态。")
    }
    try JSONEncoder().encode(transaction).write(to: url, options: .atomic)
  }

  private static func readPendingTransaction() -> PendingTransaction? {
    guard let url = pendingTransactionURL(), let data = try? Data(contentsOf: url) else {
      return nil
    }
    return try? JSONDecoder().decode(PendingTransaction.self, from: data)
  }

  private static func removePendingTransaction() {
    guard let url = pendingTransactionURL() else { return }
    try? FileManager.default.removeItem(at: url)
  }

  private static func applicationSupportDirectory() -> URL? {
    guard
      let root = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first
    else { return nil }
    let directory = root.appendingPathComponent("IsLandToken", isDirectory: true)
    try? FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    return directory
  }

  private static func installationResultURL() -> URL? {
    applicationSupportDirectory()?.appendingPathComponent("last-update-failure.json")
  }

  private static func writeInstallationFailure(version: String, error: Error) {
    guard let url = installationResultURL() else { return }
    let result = InstallationResult(
      version: version, message: error.localizedDescription, createdAt: Date())
    guard let data = try? JSONEncoder().encode(result) else { return }
    try? data.write(to: url, options: .atomic)
  }

  private static func runProcess(
    _ executable: String, arguments: [String], timeout: TimeInterval
  ) throws -> Data {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "islandtoken-command-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: false,
      attributes: [.posixPermissions: 0o700])
    defer { try? FileManager.default.removeItem(at: directory) }
    let standardOutput = directory.appendingPathComponent("stdout")
    let standardError = directory.appendingPathComponent("stderr")
    FileManager.default.createFile(
      atPath: standardOutput.path, contents: nil, attributes: [.posixPermissions: 0o600])
    FileManager.default.createFile(
      atPath: standardError.path, contents: nil, attributes: [.posixPermissions: 0o600])
    let outputHandle = try FileHandle(forWritingTo: standardOutput)
    let errorHandle = try FileHandle(forWritingTo: standardError)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = outputHandle
    process.standardError = errorHandle
    process.standardInput = FileHandle.nullDevice
    do {
      try process.run()
    } catch {
      try? outputHandle.close()
      try? errorHandle.close()
      throw error
    }
    let deadline = Date().addingTimeInterval(timeout)
    while process.isRunning, Date() < deadline { usleep(100_000) }
    if process.isRunning {
      process.terminate()
      usleep(200_000)
      if process.isRunning { kill(process.processIdentifier, SIGKILL) }
      process.waitUntilExit()
      try? outputHandle.close()
      try? errorHandle.close()
      throw UpdateInstallationError.message(
        "执行 \(URL(fileURLWithPath: executable).lastPathComponent) 超时。")
    }
    try? outputHandle.close()
    try? errorHandle.close()
    let output = (try? Data(contentsOf: standardOutput)) ?? Data()
    guard process.terminationStatus == 0 else {
      let detail = ((try? String(contentsOf: standardError, encoding: .utf8)) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      throw UpdateInstallationError.message(
        "\(URL(fileURLWithPath: executable).lastPathComponent) 执行失败"
          + (detail.isEmpty ? "。" : "：\(detail)"))
    }
    return output
  }

  private static func runCancellableProcess(
    _ executable: String, arguments: [String], timeout: TimeInterval
  ) async throws -> Data {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "islandtoken-command-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: false,
      attributes: [.posixPermissions: 0o700])
    defer { try? FileManager.default.removeItem(at: directory) }

    let standardOutput = directory.appendingPathComponent("stdout")
    let standardError = directory.appendingPathComponent("stderr")
    FileManager.default.createFile(
      atPath: standardOutput.path, contents: nil, attributes: [.posixPermissions: 0o600])
    FileManager.default.createFile(
      atPath: standardError.path, contents: nil, attributes: [.posixPermissions: 0o600])
    let outputHandle = try FileHandle(forWritingTo: standardOutput)
    let errorHandle = try FileHandle(forWritingTo: standardError)
    defer {
      try? outputHandle.close()
      try? errorHandle.close()
    }

    let processBox = CancellableProcessBox()
    return try await withTaskCancellationHandler {
      try Task.checkCancellation()
      let process = Process()
      process.executableURL = URL(fileURLWithPath: executable)
      process.arguments = arguments
      process.standardOutput = outputHandle
      process.standardError = errorHandle
      process.standardInput = FileHandle.nullDevice
      do {
        try process.run()
      } catch {
        if Task.isCancelled { throw CancellationError() }
        throw error
      }
      processBox.store(process)

      let deadline = Date().addingTimeInterval(timeout)
      do {
        while process.isRunning {
          try Task.checkCancellation()
          guard Date() < deadline else {
            stop(process)
            throw UpdateInstallationError.message(
              "执行 \(URL(fileURLWithPath: executable).lastPathComponent) 超时。")
          }
          try await Task.sleep(for: .milliseconds(100))
        }
        try Task.checkCancellation()
      } catch is CancellationError {
        stop(process)
        throw CancellationError()
      }

      try? outputHandle.close()
      try? errorHandle.close()
      let output = (try? Data(contentsOf: standardOutput)) ?? Data()
      guard process.terminationStatus == 0 else {
        let detail = ((try? String(contentsOf: standardError, encoding: .utf8)) ?? "")
          .trimmingCharacters(in: .whitespacesAndNewlines)
        throw UpdateInstallationError.message(
          "\(URL(fileURLWithPath: executable).lastPathComponent) 执行失败"
            + (detail.isEmpty ? "。" : "：\(detail)"))
      }
      return output
    } onCancel: {
      processBox.cancel()
    }
  }
}

private final class DownloadTaskBox: @unchecked Sendable {
  private let lock = NSLock()
  private var downloadTask: URLSessionDownloadTask?
  private var progressTask: Task<Void, Never>?
  private var cancelled = false
  private var finished = false

  func store(_ task: URLSessionDownloadTask) {
    lock.lock()
    let shouldCancel = cancelled || finished
    if !shouldCancel { downloadTask = task }
    lock.unlock()
    if shouldCancel { task.cancel() }
  }

  func store(poller task: Task<Void, Never>) {
    lock.lock()
    let shouldCancel = cancelled || finished
    progressTask = task
    lock.unlock()
    if shouldCancel { task.cancel() }
  }

  func cancel() {
    lock.lock()
    cancelled = true
    let downloadTask = downloadTask
    let progressTask = progressTask
    lock.unlock()
    progressTask?.cancel()
    downloadTask?.cancel()
  }

  func markDownloadFinished() {
    lock.lock()
    finished = true
    downloadTask = nil
    let progressTask = progressTask
    lock.unlock()
    progressTask?.cancel()
  }

  func takeProgressTask() -> Task<Void, Never>? {
    lock.lock()
    let progressTask = progressTask
    self.progressTask = nil
    lock.unlock()
    return progressTask
  }

  func finish() {
    cancel()
    lock.lock()
    finished = true
    downloadTask = nil
    progressTask = nil
    lock.unlock()
  }
}

private final class CancellableProcessBox: @unchecked Sendable {
  private let lock = NSLock()
  private var process: Process?
  private var cancelled = false

  func store(_ process: Process) {
    lock.lock()
    let shouldCancel = cancelled
    if !shouldCancel { self.process = process }
    lock.unlock()
    if shouldCancel, process.isRunning { process.terminate() }
  }

  func cancel() {
    lock.lock()
    cancelled = true
    let process = process
    lock.unlock()
    if let process, process.isRunning { process.terminate() }
  }
}

enum UpdateInstallationError: LocalizedError {
  case message(String)

  static func posix(_ operation: String) -> UpdateInstallationError {
    .message("\(operation)：\(String(cString: strerror(errno)))。")
  }

  var errorDescription: String? {
    switch self {
    case .message(let text): text
    }
  }
}
