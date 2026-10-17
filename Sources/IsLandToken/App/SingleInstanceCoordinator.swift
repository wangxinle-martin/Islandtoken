import AppKit
import Darwin
import Foundation

@MainActor
final class SingleInstanceCoordinator {
  private static let fallbackBundleIdentifier = "com.wangxinle.IsLandToken"
  private var lockFileDescriptor: Int32 = -1

  func claimPrimaryInstance(ignoringLegacyExecutable: URL? = nil) -> Bool {
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? Self.fallbackBundleIdentifier
    guard let lockURL = makeLockURL(bundleIdentifier: bundleIdentifier) else { return false }

    let descriptor = lockURL.withUnsafeFileSystemRepresentation { path -> Int32 in
      guard let path else { return -1 }
      return Darwin.open(
        path, O_CREAT | O_RDWR | O_CLOEXEC, mode_t(S_IRUSR | S_IWUSR))
    }
    guard descriptor >= 0 else {
      NSLog("IsLandToken could not open its single-instance lock (errno %d).", errno)
      return false
    }

    if Darwin.lockf(descriptor, F_TLOCK, 0) != 0 {
      let lockError = errno
      guard lockError == EACCES || lockError == EAGAIN else {
        NSLog("IsLandToken could not acquire its single-instance lock (errno %d).", lockError)
        Darwin.close(descriptor)
        return false
      }
      if activateLockOwner(from: descriptor, bundleIdentifier: bundleIdentifier) {
        Darwin.close(descriptor)
        return false
      }
      // The previous owner may have exited while focus handoff was being resolved.
      // Retry once so this launch can take over instead of leaving no instance.
      guard Darwin.lseek(descriptor, 0, SEEK_SET) >= 0,
        Darwin.lockf(descriptor, F_TLOCK, 0) == 0
      else {
        Darwin.close(descriptor)
        return false
      }
    }

    // Earlier releases did not take the file lock. If one of those versions is
    // already fully running, keep it as the primary instance for this launch.
    if let legacyInstance = runningApplications(
      bundleIdentifier: bundleIdentifier,
      ignoringExecutable: ignoringLegacyExecutable
    )
    .filter(\.isFinishedLaunching)
    .min(by: Self.launchedBefore) {
      activate(legacyInstance)
      Darwin.close(descriptor)
      return false
    }

    lockFileDescriptor = descriptor
    writeOwnerPID(to: descriptor)
    return true
  }

  deinit {
    if lockFileDescriptor >= 0 { Darwin.close(lockFileDescriptor) }
  }

  private func makeLockURL(bundleIdentifier: String) -> URL? {
    guard
      let applicationSupport = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first
    else {
      NSLog("IsLandToken could not locate Application Support for its single-instance lock.")
      return nil
    }
    let directory =
      applicationSupport
      .appendingPathComponent("IsLandToken", isDirectory: true)
      .appendingPathComponent("InstanceLocks", isDirectory: true)
    do {
      try FileManager.default.createDirectory(
        at: directory, withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700])
      return directory.appendingPathComponent("\(bundleIdentifier).lock")
    } catch {
      NSLog("IsLandToken could not create its single-instance lock directory: %@", "\(error)")
      return nil
    }
  }

  private func runningApplications(
    bundleIdentifier: String, ignoringExecutable: URL? = nil
  ) -> [NSRunningApplication] {
    let currentPID = ProcessInfo.processInfo.processIdentifier
    let ignored = ignoringExecutable?.resolvingSymlinksInPath()
    return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
      .filter { !$0.isTerminated && $0.processIdentifier != currentPID }
      .filter { application in
        guard let ignored else { return true }
        return application.executableURL?.resolvingSymlinksInPath() != ignored
      }
  }

  private func activateLockOwner(from descriptor: Int32, bundleIdentifier: String) -> Bool {
    // The winner may still be between lockf() and publishing its PID. Retry only
    // long enough to hand focus back without delaying duplicate-launch shutdown.
    for attempt in 0..<6 {
      if let ownerPID = readOwnerPID(from: descriptor),
        let owner = NSRunningApplication(processIdentifier: ownerPID),
        owner.bundleIdentifier == bundleIdentifier, !owner.isTerminated
      {
        activate(owner)
        return true
      }
      if attempt < 5 { usleep(40_000) }
    }
    // Only a fully launched fallback is safe to activate; another unfinished
    // process in the list may be a concurrent duplicate that is also exiting.
    if let owner = runningApplications(bundleIdentifier: bundleIdentifier)
      .filter(\.isFinishedLaunching)
      .min(by: Self.launchedBefore)
    {
      activate(owner)
      return true
    }
    return false
  }

  private func activate(_ application: NSRunningApplication) {
    application.activate(options: [.activateAllWindows])
  }

  private func writeOwnerPID(to descriptor: Int32) {
    let bytes = Array("\(ProcessInfo.processInfo.processIdentifier)\n".utf8)
    guard Darwin.ftruncate(descriptor, 0) == 0 else {
      let error = errno
      NSLog("IsLandToken could not clear its single-instance lock owner PID (errno %d).", error)
      return
    }
    guard Darwin.lseek(descriptor, 0, SEEK_SET) >= 0 else {
      let error = errno
      NSLog("IsLandToken could not seek its single-instance lock owner PID (errno %d).", error)
      return
    }

    bytes.withUnsafeBytes { buffer in
      guard let address = buffer.baseAddress else {
        NSLog("IsLandToken could not encode its single-instance lock owner PID.")
        return
      }

      var offset = 0
      while offset < buffer.count {
        let written = Darwin.write(
          descriptor,
          address.advanced(by: offset),
          buffer.count - offset)
        if written > 0 {
          offset += written
          continue
        }
        let error = errno
        if written == -1, error == EINTR {
          continue
        }

        if written == 0 {
          NSLog("IsLandToken wrote zero bytes to its single-instance lock owner PID.")
        } else {
          NSLog("IsLandToken could not write its single-instance lock owner PID (errno %d).", error)
        }
        return
      }
    }
  }

  private func readOwnerPID(from descriptor: Int32) -> pid_t? {
    guard Darwin.lseek(descriptor, 0, SEEK_SET) >= 0 else { return nil }
    var bytes = [UInt8](repeating: 0, count: 32)
    let count = bytes.withUnsafeMutableBytes { buffer in
      Darwin.read(descriptor, buffer.baseAddress, buffer.count)
    }
    guard count > 0,
      let value = String(bytes: bytes.prefix(Int(count)), encoding: .utf8),
      let pid = pid_t(value.trimmingCharacters(in: .whitespacesAndNewlines)), pid > 0
    else { return nil }
    return pid
  }

  private static func launchedBefore(
    _ lhs: NSRunningApplication, _ rhs: NSRunningApplication
  ) -> Bool {
    let lhsDate = lhs.launchDate ?? .distantFuture
    let rhsDate = rhs.launchDate ?? .distantFuture
    if lhsDate != rhsDate { return lhsDate < rhsDate }
    return lhs.processIdentifier < rhs.processIdentifier
  }
}
