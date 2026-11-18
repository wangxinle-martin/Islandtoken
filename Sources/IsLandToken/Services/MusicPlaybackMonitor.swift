import CoreAudio
import Foundation

enum MusicPlaybackMonitor {
  private static let playerBundleIDs = [
    "com.apple.music",
    "com.spotify.client",
    "com.netease.163music",
    "com.tencent.qqmusicmac",
    "com.soda.music",
    "cn.toside.music.desktop",
  ]

  static func playingProcesses() -> [AudioObjectID] {
    let system = AudioObjectID(kAudioObjectSystemObject)
    var address = property(kAudioHardwarePropertyProcessObjectList)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr,
      size >= MemoryLayout<AudioObjectID>.stride
    else { return [] }

    var processes = [AudioObjectID](
      repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.stride)
    let status = processes.withUnsafeMutableBytes { buffer in
      AudioObjectGetPropertyData(system, &address, 0, nil, &size, buffer.baseAddress!)
    }
    guard status == noErr else { return [] }
    return processes.prefix(Int(size) / MemoryLayout<AudioObjectID>.stride).filter { process in
      var running: UInt32 = 0
      var runningSize = UInt32(MemoryLayout.size(ofValue: running))
      var runningAddress = property(kAudioProcessPropertyIsRunningOutput)
      guard AudioObjectGetPropertyData(
        process, &runningAddress, 0, nil, &runningSize, &running
      ) == noErr, running != 0 else { return false }

      var bundle: Unmanaged<CFString>?
      var bundleSize = UInt32(MemoryLayout.size(ofValue: bundle))
      var bundleAddress = property(kAudioProcessPropertyBundleID)
      guard AudioObjectGetPropertyData(
        process, &bundleAddress, 0, nil, &bundleSize, &bundle
      ) == noErr, let bundle else { return false }

      let id = (bundle.takeRetainedValue() as String).lowercased()
      return playerBundleIDs.contains { id == $0 || id.hasPrefix($0 + ".") }
    }
  }

  private static func property(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
      mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain)
  }
}
