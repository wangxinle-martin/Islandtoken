import Foundation
import IslandCore

/// Uses executable names and cumulative CPU time only, never process arguments or conversations.
actor AgentActivityMonitor {
  private var previous: [String: Double] = [:]
  private var lastActivity: Date?

  func isActive(providers: [Provider], now: Date = Date()) async -> Bool {
    guard
      let data = try? await ProcessRunner.run(
        "/bin/ps", arguments: ["-axo", "pid=,time=,comm="], timeout: 5),
      let output = String(data: data, encoding: .utf8)
    else { return false }
    return observe(output: output, providers: providers, now: now)
  }

  func observe(output: String, providers: [Provider], now: Date) -> Bool {
    let names = providers.map { $0.rawValue.lowercased() }
    var current: [String: Double] = [:]
    for line in output.split(separator: "\n") {
      let fields = line.split(maxSplits: 2, whereSeparator: { $0.isWhitespace })
      guard fields.count == 3 else { continue }
      let executable = String(fields[2]).lowercased()
      let basename = URL(fileURLWithPath: executable).lastPathComponent
      guard
        names.contains(where: { name in
          basename == name || basename.hasPrefix(name + " ")
            || executable.contains("/" + name + ".app/")
        })
      else { continue }
      let parts = fields[1].split(separator: ":").compactMap { Double($0) }
      guard !parts.isEmpty else { continue }
      let cpu = parts.reduce(0) { $0 * 60 + $1 }
      let key = String(fields[0]) + executable
      current[key] = cpu
      if let old = previous[key], cpu - old >= 0.2 {
        lastActivity = now
      } else if previous[key] == nil {
        lastActivity = now
      }
    }
    previous = current
    return lastActivity.map { now.timeIntervalSince($0) < 120 } ?? false
  }
}
