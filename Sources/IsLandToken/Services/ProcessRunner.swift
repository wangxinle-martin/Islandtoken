import Darwin
import Foundation
import IslandCore

enum ProcessRunner {
  /// No shell interpolation; bounded runtime and disk output avoid pipe deadlocks.
  static func run(_ executable: String, arguments: [String], timeout: TimeInterval = 55)
    async throws -> Data
  {
    let task = Task.detached(priority: .utility) {
      let fm = FileManager.default
      let directory = fm.temporaryDirectory.appendingPathComponent(
        "islandtoken-\(UUID().uuidString)")
      try fm.createDirectory(
        at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
      defer { try? fm.removeItem(at: directory) }
      let file = directory.appendingPathComponent("output")
      fm.createFile(atPath: file.path, contents: nil, attributes: [.posixPermissions: 0o600])
      let output = try FileHandle(forWritingTo: file)
      defer { try? output.close() }
      let process = Process()
      process.executableURL = URL(fileURLWithPath: executable)
      process.arguments = arguments
      process.standardOutput = output
      process.standardError = FileHandle.nullDevice
      process.standardInput = FileHandle.nullDevice
      var environment = ProcessInfo.processInfo.environment
      environment["PATH"] =
        "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (environment["PATH"] ?? "")
      process.environment = environment
      try process.run()
      let deadline = Date().addingTimeInterval(timeout)
      defer {
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
      }
      while process.isRunning {
        try Task.checkCancellation()
        let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if Date() > deadline || size > 8_000_000 {
          process.terminate()
          try? await Task.sleep(for: .milliseconds(150))
          if process.isRunning { kill(process.processIdentifier, SIGKILL) }
          process.waitUntilExit()
          throw UsageError.message("采集超时或响应过大；请检查平台状态后重试。")
        }
        try await Task.sleep(for: .milliseconds(80))
      }
      // A fast process can exit before the polling loop observes its final output size.
      try Task.checkCancellation()
      let finalSize = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      guard finalSize <= 8_000_000 else {
        throw UsageError.message("采集响应过大，请检查平台状态后重试。")
      }
      let data = try Data(contentsOf: file)
      guard !data.isEmpty else { throw UsageError.message("采集程序未返回数据，请检查本机配置。") }
      return data
    }
    return try await withTaskCancellationHandler {
      try await task.value
    } onCancel: {
      task.cancel()
    }
  }
}
