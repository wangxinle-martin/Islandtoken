import CoreAudio
import Foundation

final class MusicAudioMeter {
  private var processes: [AudioObjectID] = []
  private var tap: AudioObjectID = 0
  private var device: AudioObjectID = 0
  private var io: AudioDeviceIOProcID?
  private let queue = DispatchQueue(label: "IsLandToken.music-meter", qos: .userInteractive)
  private let samples = MusicAudioLevels()

  var levels: MusicWaveLevels? { samples.read() }

  // Only the controller's main actor changes the tap and its aggregate device.
  func follow(_ playingProcesses: [AudioObjectID]) {
    guard #available(macOS 14.2, *), playingProcesses != processes else { return }
    stop()
    processes = playingProcesses
    guard !processes.isEmpty else { return }

    let description = CATapDescription(monoMixdownOfProcesses: processes)
    description.name = "IsLandToken Music Wave"
    description.isPrivate = true
    description.muteBehavior = .unmuted
    guard AudioHardwareCreateProcessTap(description, &tap) == noErr else { return }

    var format = AudioStreamBasicDescription()
    var size = UInt32(MemoryLayout.size(ofValue: format))
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioTapPropertyFormat, mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectGetPropertyData(tap, &address, 0, nil, &size, &format) == noErr,
      format.mFormatID == kAudioFormatLinearPCM, format.mBitsPerChannel == 32,
      format.mFormatFlags & kAudioFormatFlagIsFloat != 0, format.mSampleRate > 0
    else { stop(); return }

    let configuration: [String: Any] = [
      kAudioAggregateDeviceNameKey: "IsLandToken Music Wave",
      kAudioAggregateDeviceUIDKey: UUID().uuidString,
      kAudioAggregateDeviceIsPrivateKey: true,
      kAudioAggregateDeviceTapAutoStartKey: true,
      kAudioAggregateDeviceTapListKey: [[
        kAudioSubTapUIDKey: description.uuid.uuidString,
        kAudioSubTapDriftCompensationKey: true,
      ]],
    ]
    guard AudioHardwareCreateAggregateDevice(configuration as CFDictionary, &device) == noErr
    else { stop(); return }

    let analyzer = MusicBufferAnalyzer(sampleRate: format.mSampleRate, levels: samples)
    guard AudioDeviceCreateIOProcIDWithBlock(&io, device, queue, {
      _, input, _, _, _ in analyzer.measure(input)
    }) == noErr, let io, AudioDeviceStart(device, io) == noErr
    else { stop(); return }
  }

  private func stop() {
    if let io {
      AudioDeviceStop(device, io)
      AudioDeviceDestroyIOProcID(device, io)
      self.io = nil
    }
    if device != 0 {
      AudioHardwareDestroyAggregateDevice(device)
      device = 0
    }
    if #available(macOS 14.2, *), tap != 0 {
      AudioHardwareDestroyProcessTap(tap)
      tap = 0
    }
    samples.clear()
  }

  deinit { stop() }
}

private final class MusicAudioLevels {
  private let lock = NSLock()
  private var levels: MusicWaveLevels?
  private var updatedAt: UInt64 = 0

  func read() -> MusicWaveLevels? {
    lock.withLock {
      let age = DispatchTime.now().uptimeNanoseconds - updatedAt
      return age < 250_000_000 ? levels : nil
    }
  }

  func update(_ next: MusicWaveLevels) {
    // Never wait for the UI while Core Audio is delivering a buffer.
    guard lock.try() else { return }
    defer { lock.unlock() }
    let previous = levels ?? next
    levels = MusicWaveLevels(
      level: max(next.level, previous.level * 0.72),
      bass: max(next.bass, previous.bass * 0.76),
      midrange: max(next.midrange, previous.midrange * 0.70),
      treble: max(next.treble, previous.treble * 0.65))
    updatedAt = DispatchTime.now().uptimeNanoseconds
  }

  func clear() { lock.withLock { levels = nil } }
}

private final class MusicBufferAnalyzer {
  private let levels: MusicAudioLevels
  private let bassCoefficient: Float
  private let midCoefficient: Float
  private var bass: Float = 0
  private var mid: Float = 0

  init(sampleRate: Double, levels: MusicAudioLevels) {
    self.levels = levels
    bassCoefficient = Float(1 - exp(-2 * .pi * 180 / sampleRate))
    midCoefficient = Float(1 - exp(-2 * .pi * 2_000 / sampleRate))
  }

  func measure(_ input: UnsafePointer<AudioBufferList>) {
    // The tap downmixes to mono. Measure overall level and three frequency bands.
    let buffer = input.pointee.mBuffers
    guard let data = buffer.mData else { return }
    let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.stride
    guard count > 0 else { return }
    let values = data.assumingMemoryBound(to: Float.self)
    var power: Float = 0
    var bassPower: Float = 0
    var midrangePower: Float = 0
    var treblePower: Float = 0
    for index in 0..<count {
      let value = values[index]
      bass += bassCoefficient * (value - bass)
      mid += midCoefficient * (value - mid)
      let midrange = mid - bass
      let treble = value - mid
      power += value * value
      bassPower += bass * bass
      midrangePower += midrange * midrange
      treblePower += treble * treble
    }
    func intensity(_ power: Float, gain: Double) -> Double {
      min(1, sqrt(Double(power) / Double(count)) * gain)
    }
    levels.update(MusicWaveLevels(
      level: intensity(power, gain: 4),
      bass: intensity(bassPower, gain: 6),
      midrange: intensity(midrangePower, gain: 8),
      treble: intensity(treblePower, gain: 14)))
  }
}
