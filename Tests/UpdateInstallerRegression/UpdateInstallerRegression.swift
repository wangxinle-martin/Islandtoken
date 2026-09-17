import Foundation

@main
enum UpdateInstallerRegression {
  static func main() throws {
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

    print("PASS updater assets, checksum, guarded acknowledgement, and atomic rollback swap")
  }
}
