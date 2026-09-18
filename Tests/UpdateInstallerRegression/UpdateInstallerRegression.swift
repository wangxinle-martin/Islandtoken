import Foundation

@main
enum UpdateInstallerRegression {
  static func main() async throws {
    let names = AppUpdateInstaller.assetNames(version: "0.3.0", architecture: "arm64")
    precondition(names.package == "IsLandToken-0.3.0-arm64.dmg")
    precondition(names.checksum == "IsLandToken-0.3.0-arm64.dmg.sha256")

    let digest = String(repeating: "a", count: 64)
    precondition(
      AppUpdateInstaller.expectedChecksum(
        in: "\(digest)  \(names.package)\n", packageName: names.package) == digest)
    precondition(
      AppUpdateInstaller.expectedChecksum(
        in: "\(digest)  wrong.dmg\n", packageName: names.package) == nil)
    precondition(
      AppUpdateInstaller.expectedChecksum(
        in: "not-a-checksum  \(names.package)\n", packageName: names.package) == nil)

    precondition(AppUpdateInstaller.downloadFraction(completedBytes: -25, totalBytes: 100) == 0)
    precondition(AppUpdateInstaller.downloadFraction(completedBytes: 0, totalBytes: 100) == 0)
    precondition(AppUpdateInstaller.downloadFraction(completedBytes: 50, totalBytes: 100) == 0.5)
    precondition(AppUpdateInstaller.downloadFraction(completedBytes: 125, totalBytes: 100) == 1)
    precondition(AppUpdateInstaller.downloadFraction(completedBytes: 50, totalBytes: 0) == 0)
    precondition(AppUpdateInstaller.downloadFraction(completedBytes: 50, totalBytes: -100) == 0)

    let fractions = [-50, 0, 1, 25, 50, 99, 100, 150].map {
      AppUpdateInstaller.downloadFraction(completedBytes: Int64($0), totalBytes: 100)
    }
    precondition(fractions.allSatisfy { (0...1).contains($0) })
    precondition(zip(fractions, fractions.dropFirst()).allSatisfy { $0 <= $1 })

    // Cancellation can win before URLSessionDownloadTask is created. The session must
    // remain valid long enough to create, bind, and immediately cancel that task.
    let startGate = AsyncStream<Void>.makeStream()
    let cancelledDestination = FileManager.default.temporaryDirectory.appendingPathComponent(
      "islandtoken-cancelled-download-\(UUID().uuidString)")
    let cancelledDownload = Task {
      var iterator = startGate.stream.makeAsyncIterator()
      _ = await iterator.next()
      try await AppUpdateInstaller.download(
        asset: AppUpdateAsset(
          name: "cancelled.dmg",
          browserDownloadURL: URL(string: "http://192.0.2.1/islandtoken-test")!, size: 1),
        to: cancelledDestination, completedBytes: 0, totalBytes: 1, progress: nil)
    }
    cancelledDownload.cancel()
    startGate.continuation.yield(())
    startGate.continuation.finish()
    do {
      try await cancelledDownload.value
      preconditionFailure("A pre-cancelled download must not succeed")
    } catch is CancellationError {
      // Expected.
    } catch {
      preconditionFailure("A pre-cancelled download returned \(error)")
    }
    precondition(!FileManager.default.fileExists(atPath: cancelledDestination.path))

    let acknowledgementDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "islandtoken-update-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: acknowledgementDirectory, withIntermediateDirectories: false,
      attributes: [.posixPermissions: 0o700])
    defer { try? FileManager.default.removeItem(at: acknowledgementDirectory) }
    let acknowledgement = acknowledgementDirectory.appendingPathComponent("launch-ack")
    precondition(
      AppUpdateInstaller.handleLaunchAcknowledgementIfRequested(
        arguments: ["test", AppUpdateInstaller.acknowledgementFlag, acknowledgement.path]))
    // A plausible temporary path is insufficient without the matching persisted transaction.
    precondition(!FileManager.default.fileExists(atPath: acknowledgement.path))
    precondition(
      !AppUpdateInstaller.isValidatedUpdateRelaunch(
        arguments: ["test", AppUpdateInstaller.acknowledgementFlag, acknowledgement.path]))
    let unsafeAcknowledgement = acknowledgementDirectory.appendingPathComponent("other-file")
    precondition(
      AppUpdateInstaller.handleLaunchAcknowledgementIfRequested(
        arguments: ["test", AppUpdateInstaller.acknowledgementFlag, unsafeAcknowledgement.path]))
    precondition(!FileManager.default.fileExists(atPath: unsafeAcknowledgement.path))
    precondition(
      !AppUpdateInstaller.handleLaunchAcknowledgementIfRequested(arguments: ["test"]))

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "islandtoken-swap-test-\(UUID().uuidString)", isDirectory: true)
    let current = directory.appendingPathComponent("current.app", isDirectory: true)
    let staged = directory.appendingPathComponent("staged.app", isDirectory: true)
    try FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try Data("old".utf8).write(to: current.appendingPathComponent("marker"))
    try Data("new".utf8).write(to: staged.appendingPathComponent("marker"))

    try AppUpdateInstaller.atomicSwap(current, staged)
    let installed = try String(
      contentsOf: current.appendingPathComponent("marker"), encoding: .utf8)
    let backup = try String(
      contentsOf: staged.appendingPathComponent("marker"), encoding: .utf8)
    precondition(installed == "new")
    precondition(backup == "old")
    try AppUpdateInstaller.atomicSwap(current, staged)
    let restored = try String(
      contentsOf: current.appendingPathComponent("marker"), encoding: .utf8)
    precondition(restored == "old")

    print(
      "PASS updater assets, progress, pre-cancel, guarded acknowledgement, and atomic rollback swap"
    )
  }
}
