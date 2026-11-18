import IslandCore
import SwiftUI

/// Which outer Island edge joins the physical Mac camera housing.
/// A joined edge remains straight so it visually meets the hardware notch.
enum IslandNotchAttachment: Equatable {
  case none
  case leading
  case trailing

  init(_ visibility: IslandSideVisibility?) {
    switch visibility {
    case .left: self = .trailing
    case .right: self = .leading
    case .both, nil: self = .none
    }
  }
}

/// The top edge flares outward into the screen edge; bottom corners remain convex.
/// Shared by rendering and mouse hit testing so transparent shoulders pass clicks through.
struct IslandShape: Shape {
  /// Interpolate this value with the shell width so the lower corners do not
  /// jump between compact and popup radii at the start of a transition.
  var expansionProgress: CGFloat
  var notchAttachment: IslandNotchAttachment = .none

  init(expansionProgress: CGFloat, notchAttachment: IslandNotchAttachment = .none) {
    self.expansionProgress = min(1, max(0, expansionProgress))
    self.notchAttachment = notchAttachment
  }

  init(expanded: Bool, notchAttachment: IslandNotchAttachment = .none) {
    self.init(expansionProgress: expanded ? 1 : 0, notchAttachment: notchAttachment)
  }

  var animatableData: CGFloat {
    get { expansionProgress }
    set { expansionProgress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    let shoulder = min(12.0, rect.height / 3)
    let bottom = min(12.0 + 12.0 * expansionProgress, (rect.height - shoulder) / 2)
    let left = rect.minX + shoulder
    let right = rect.maxX - shoulder
    let top = rect.minY
    let base = rect.maxY
    let k = 0.5522847498
    var p = Path()
    p.move(to: CGPoint(x: rect.minX, y: top))
    p.addLine(to: CGPoint(x: rect.maxX, y: top))
    if notchAttachment == .trailing {
      p.addLine(to: CGPoint(x: rect.maxX, y: base - bottom))
    } else {
      p.addCurve(
        to: CGPoint(x: right, y: top + shoulder),
        control1: CGPoint(x: rect.maxX - shoulder * k, y: top),
        control2: CGPoint(x: right, y: top + shoulder * (1 - k)))
      p.addLine(to: CGPoint(x: right, y: base - bottom))
    }
    p.addQuadCurve(to: CGPoint(x: right - bottom, y: base), control: CGPoint(x: right, y: base))
    p.addLine(to: CGPoint(x: left + bottom, y: base))
    p.addQuadCurve(to: CGPoint(x: left, y: base - bottom), control: CGPoint(x: left, y: base))
    if notchAttachment == .leading {
      p.addLine(to: CGPoint(x: rect.minX, y: top))
    } else {
      p.addLine(to: CGPoint(x: left, y: top + shoulder))
      p.addCurve(
        to: CGPoint(x: rect.minX, y: top), control1: CGPoint(x: left, y: top + shoulder * (1 - k)),
        control2: CGPoint(x: rect.minX + shoulder * k, y: top))
    }
    p.closeSubpath()
    return p
  }
}

/// Open outline: never draws the horizontal edge that meets the physical notch.
struct IslandLowerEdge: Shape {
  var expansionProgress: CGFloat
  var notchAttachment: IslandNotchAttachment = .none

  init(expansionProgress: CGFloat, notchAttachment: IslandNotchAttachment = .none) {
    self.expansionProgress = min(1, max(0, expansionProgress))
    self.notchAttachment = notchAttachment
  }

  init(expanded: Bool, notchAttachment: IslandNotchAttachment = .none) {
    self.init(expansionProgress: expanded ? 1 : 0, notchAttachment: notchAttachment)
  }

  var animatableData: CGFloat {
    get { expansionProgress }
    set { expansionProgress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    let shoulder = min(12.0, rect.height / 3)
    let bottom = min(12.0 + 12.0 * expansionProgress, (rect.height - shoulder) / 2)
    let left = rect.minX + shoulder
    let right = rect.maxX - shoulder
    let k = 0.5522847498
    var p = Path()
    if notchAttachment == .trailing {
      p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
    } else {
      p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
      p.addCurve(
        to: CGPoint(x: right, y: rect.minY + shoulder),
        control1: CGPoint(x: rect.maxX - shoulder * k, y: rect.minY),
        control2: CGPoint(x: right, y: rect.minY + shoulder * (1 - k)))
      p.addLine(to: CGPoint(x: right, y: rect.maxY - bottom))
    }
    p.addQuadCurve(
      to: CGPoint(x: right - bottom, y: rect.maxY), control: CGPoint(x: right, y: rect.maxY))
    p.addLine(to: CGPoint(x: left + bottom, y: rect.maxY))
    p.addQuadCurve(
      to: CGPoint(x: left, y: rect.maxY - bottom), control: CGPoint(x: left, y: rect.maxY))
    if notchAttachment != .leading {
      p.addLine(to: CGPoint(x: left, y: rect.minY + shoulder))
      p.addCurve(
        to: CGPoint(x: rect.minX, y: rect.minY),
        control1: CGPoint(x: left, y: rect.minY + shoulder * (1 - k)),
        control2: CGPoint(x: rect.minX + shoulder * k, y: rect.minY))
    }
    return p
  }
}

struct DigitFlipText: View {
  let text: String
  let active: Bool
  let color: Color
  var showsPercentSign = false
  var alertColor: Color? = nil
  var body: some View {
    HStack(spacing: 0) {
      HStack(spacing: 0) {
        ForEach(Array(text.enumerated()), id: \.offset) { index, character in
          if let digit = character.wholeNumberValue {
            RollingDigit(digit: digit, index: index, active: active)
          } else {
            Text(String(character))
          }
        }
      }
      .frame(height: 16)
      .overlay(alignment: .bottom) {
        if let alertColor {
          Circle().fill(alertColor).frame(width: 3, height: 3)
            .offset(y: 2)
        }
      }
      if showsPercentSign { Text("%") }
    }
    .font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
    .foregroundStyle(color)
    .frame(height: 20)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(text + (showsPercentSign ? "%" : ""))
  }
}

private struct RollingDigit: View {
  let digit: Int
  let index: Int
  let active: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var startedAt = Date()
  @State private var running = false
  @State private var settlingAt: Date?
  @State private var settleStart = 0.0
  @State private var settleTarget = 0.0
  @State private var settleDuration = 1.0
  private var speed: Double { 32 + Double(index % 4) * 4 }

  private func position(at date: Date) -> Double {
    guard let settlingAt else { return max(0, date.timeIntervalSince(startedAt)) * speed }
    let progress = min(1, max(0, date.timeIntervalSince(settlingAt) / settleDuration))
    return settleStart + (settleTarget - settleStart) * (1 - pow(1 - progress, 3))
  }

  var body: some View {
    Text(String(digit)).hidden()
      .overlay {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !running || reduceMotion)) {
          timeline in
          if running && !reduceMotion {
            let position = position(at: timeline.date)
            let center = Int(floor(position))
            ZStack {
              ForEach(-2...2, id: \.self) { offset in
                let step = center + offset
                Text(String((step % 10 + 10) % 10))
                  .offset(y: (position - Double(step)) * 16)
              }
            }
            .frame(width: 12, height: 32)
            .mask(
              LinearGradient(
                stops: [
                  .init(color: .clear, location: 0),
                  .init(color: .white, location: 0.32),
                  .init(color: .white, location: 0.68),
                  .init(color: .clear, location: 1),
                ], startPoint: .top, endPoint: .bottom))
          } else {
            Text(String(digit))
          }
        }
      }
      .onAppear { if active { start() } }
      .onChange(of: active) { _, value in
        if value { start() } else { settle() }
      }

      .onChange(of: digit) { _, _ in
        if running && !active { settle() }
      }
      .onChange(of: reduceMotion) { _, value in if value { running = false } }
      .task(id: settlingAt) {
        guard settlingAt != nil else { return }
        do { try await Task.sleep(for: .seconds(settleDuration)) } catch { return }
        guard !active else { return }
        running = false
      }

  }

  private func start() {
    guard !reduceMotion else { return }
    startedAt = Date()
    settlingAt = nil
    running = true
  }

  private func settle() {
    guard running, !reduceMotion else { return }
    let now = Date()
    let current = position(at: now)
    // Continue forward to the actual digit, matching the cruise speed before easing out.
    let target = ceil((current + speed * 0.3 - Double(digit)) / 10) * 10 + Double(digit)
    settleStart = current
    settleTarget = target
    settleDuration = 3 * (target - current) / speed
    settlingAt = now
  }
}

struct IslandRefreshMeteor: View {
  @State private var startedAt = Date()
  @State private var scatterSeed = Double.random(in: 0...10000)
  var expanded: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { timeline in
      let cycle =
        reduceMotion
        ? 0.5
        : max(0, timeline.date.timeIntervalSince(startedAt)).truncatingRemainder(dividingBy: 2.4)
          / 2.4
      GeometryReader { geometry in
        let progress = min(1, cycle / 0.75)
        let travel = CGFloat(reduceMotion ? 0.5 : progress * progress)
        let pathWidth = geometry.size.width + 60
        let slope = geometry.size.height / max(geometry.size.width, 1)
        let x = pathWidth * travel - 30
        let y = x * slope
        let angle = atan2(geometry.size.height, max(geometry.size.width, 1))
        ZStack(alignment: .topLeading) {
          Capsule()
            .fill(
              LinearGradient(
                colors: [.clear, .cyan.opacity(0.65), .white.opacity(0.95)], startPoint: .leading,
                endPoint: .trailing)
            )
            .frame(width: 58, height: 2)
            .rotationEffect(.radians(Double(angle)), anchor: .trailing)
            .offset(x: x - 58, y: y - 1)
            .blur(radius: 0.6)
          Circle()
            .fill(Color.white)
            .frame(width: 4.5, height: 4.5)
            .shadow(color: .cyan.opacity(0.95), radius: 7)
            .shadow(color: .cyan.opacity(0.65), radius: 12)
            .offset(x: x - 2.25, y: y - 2.25)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .opacity(reduceMotion || cycle < 0.75 ? 1 : 0)
        .overlay {
          if !reduceMotion {
            Canvas { context, size in
              let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))
              for index in 0..<4 {
                let clock = elapsed + Double(index) * 0.63
                let generation = floor(clock / 2.8)
                let seed = scatterSeed + Double(index) * 37 + generation * 113
                func random(_ salt: Double) -> Double {
                  let value = sin(seed + salt * 17.3) * 43758.5453
                  return value - floor(value)
                }
                let age = clock.truncatingRemainder(dividingBy: 2.8) - random(1) * 0.7
                let duration = 0.9 + random(2) * 0.8
                guard age >= 0, age < duration else { continue }
                let progress = age / duration
                let travel = CGFloat(progress * progress)
                let start = CGPoint(x: size.width * CGFloat(random(3) * 0.55), y: -6)
                let end = CGPoint(x: min(size.width + 20, start.x + size.width * CGFloat(0.25 + random(4) * 0.5)), y: size.height + 8)
                let dx = end.x - start.x
                let dy = end.y - start.y
                let length = max(1, hypot(dx, dy))
                let head = CGPoint(x: start.x + dx * travel, y: start.y + dy * travel)
                let tailLength = CGFloat(17 + random(5) * 15)
                let tail = CGPoint(x: head.x - dx / length * tailLength, y: head.y - dy / length * tailLength)
                var path = Path()
                path.move(to: tail)
                path.addLine(to: head)
                context.stroke(path, with: .linearGradient(
                  Gradient(colors: [.clear, .cyan.opacity(0.55), .white.opacity(0.85)]),
                  startPoint: tail, endPoint: head), lineWidth: 1)
                let radius = CGFloat(0.9 + random(6) * 0.6)
                context.fill(Path(ellipseIn: CGRect(x: head.x - radius, y: head.y - radius,
                  width: radius * 2, height: radius * 2)), with: .color(.white.opacity(0.9)))
              }
            }
          }
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

struct IslandRefreshGlowBorder: View {
  var expanded: Bool
  var notchAttachment: IslandNotchAttachment = .none
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { timeline in
      let time = timeline.date.timeIntervalSinceReferenceDate
      let pulse = reduceMotion ? 0.5 : (sin(time * 6.3) + 1) / 2
      let colorPhase = (sin(time * 1.7) + 1) / 2
      // Deliberately span cyan-green to magenta-red for a high-contrast status pulse.
      let glowColor = Color(hue: 0.48 + colorPhase * 0.42, saturation: 0.96, brightness: 1.0)
      IslandLowerEdge(expanded: expanded, notchAttachment: notchAttachment)
        // Blur the stroke before applying the shadow so the island interior stays dark.
        .stroke(glowColor.opacity(0.10 + pulse * 0.90), lineWidth: 1.2 + pulse * 0.8)
        .blur(radius: 2 + pulse * 5)
        .shadow(color: glowColor.opacity(0.08 + pulse * 0.90), radius: 7 + pulse * 23)
        .shadow(color: glowColor.opacity(0.04 + pulse * 0.65), radius: 16 + pulse * 38)
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

struct IslandRefreshSparkle: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { timeline in
      let pulse =
        reduceMotion ? 0.5 : (sin(timeline.date.timeIntervalSinceReferenceDate * 4.8) + 1) / 2
      Circle()
        .fill(Color.orange.opacity(0.55 + pulse * 0.4))
        .frame(width: 2.5 + pulse * 3.5, height: 2.5 + pulse * 3.5)
        .shadow(color: .orange.opacity(0.7 + pulse * 0.25), radius: 3 + pulse * 6)
        .shadow(color: .orange.opacity(0.4), radius: 9 + pulse * 8)
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

/// Lightweight procedural effects share one clock and never participate in hit testing.
struct IslandRefreshEffects: View {
  let style: RefreshAnimationStyle
  @State private var startedAt = Date()
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { timeline in
      Canvas { context, size in
        let t = reduceMotion ? 0.6 : max(0, timeline.date.timeIntervalSince(startedAt))
        let w = size.width
        let h = size.height
        switch style {
        case .radar:
          let x = CGFloat((t / 1.8).truncatingRemainder(dividingBy: 1)) * (w + 70) - 35
          for i in 0..<24 {
            let px = x - CGFloat(i) * 2
            context.fill(
              Path(CGRect(x: px, y: 0, width: 2, height: h)),
              with: .color(.mint.opacity(0.22 * (1 - Double(i) / 24))))
          }
          context.fill(
            Path(CGRect(x: x, y: 0, width: 1.5, height: h)), with: .color(.mint.opacity(0.8)))
        case .pixels:
          for i in 0..<32 {
            let p = (t / 1.6 + Double(i) / 32).truncatingRemainder(dividingBy: 1)
            let side: CGFloat = i.isMultiple(of: 2) ? -1 : 1
            let x = w / 2 + side * w / 2 * CGFloat(1 - p * p)
            let y = h / 2 + CGFloat(sin(Double(i) * 12.3)) * h * 0.4 * CGFloat(1 - p)
            context.fill(
              Path(CGRect(x: x, y: y, width: 2.5, height: 2.5)),
              with: .color(.cyan.opacity(sin(p * .pi) * 0.75)))
          }
        case .waves:
          for i in 0..<3 {
            let p = (t / 2 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
            let radius = CGFloat(p) * w * 0.55
            context.stroke(
              Path(
                ellipseIn: CGRect(
                  x: w / 2 - radius, y: h / 2 - radius,
                  width: radius * 2, height: radius * 2)),
              with: .color(.cyan.opacity((1 - p) * 0.55)), lineWidth: 1.5)
          }
        case .rain:
          let columns = max(1, Int(w / 18))
          for i in 0..<columns {
            let p = (t * (0.65 + Double(i % 5) * 0.08) + Double(i) * 0.37).truncatingRemainder(
              dividingBy: 1)
            for j in 0..<4 {
              let y = CGFloat(p) * (h + 45) - CGFloat(j * 11)
              let value = (Int(t * 8) + i * 7 + j) % 2
              context.draw(
                Text(String(value)).font(.system(size: 9, design: .monospaced))
                  .foregroundStyle(Color.green.opacity(0.42 - Double(j) * 0.08)),
                at: CGPoint(x: CGFloat(i) * 18 + 9, y: y))
            }
          }
        default: break
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

struct MusicWaveLevels {
  let level: Double
  let bass: Double
  let midrange: Double
  let treble: Double
}

struct IslandAudioWaveBackground: View {
  let style: MusicWaveStyle
  let audioLevels: () -> MusicWaveLevels?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var startedAt = Date()

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { timeline in
      Canvas { context, size in
        let t = reduceMotion ? 1.4 : max(0, timeline.date.timeIntervalSince(startedAt))
        let levels = reduceMotion ? nil : audioLevels()
        switch style {
        case .off, .random:
          break
        case .bars, .shortLines:
          renderBands(context, size: size, time: t, levels: levels)
        case .bouncingNotes:
          renderNotes(context, size: size, time: t, levels: levels)
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private func renderNotes(
    _ context: GraphicsContext, size: CGSize, time: Double, levels: MusicWaveLevels?
  ) {
    guard size.width > 20, size.height > 12 else { return }
    let symbols = ["♪", "♫", "♩"]
    let colors: [Color] = [.mint, .cyan, .purple]
    let count = min(12, max(2, Int(size.width / 27)))
    let energy = levels.map { max($0.level, $0.bass) }
      ?? (0.45 + 0.2 * sin(time * 5))
    let treble = levels?.treble ?? 0.35
    let fontSize = min(14, size.height * 0.45)

    for index in 0..<count {
      let speed = 0.75 + Double(index % 3) * 0.15
      let cycle = time * speed + Double(index) * 0.37
      let phase = cycle.truncatingRemainder(dividingBy: 1)
      let flight = phase / 0.8
      guard flight < 1 else { continue }

      let threshold = Double(index % 5) * 0.12
      let activity = min(1, max(0, (energy - threshold) * 5))
      guard activity > 0 else { continue }

      let rise = flight * (2 - flight)
      let fade = min(1, flight / 0.12, (1 - flight) / 0.55)
      let x = size.width * (Double(index) + 0.5) / Double(count)
      let y = size.height * (0.78 - rise * 0.53)
      let color = colors[index % colors.count].opacity(fade * activity * (0.48 + treble * 0.36))
      let symbol = symbols[(index + Int(cycle)) % symbols.count]
      context.draw(
        Text(symbol)
          .font(.system(size: fontSize, weight: .semibold))
          .foregroundStyle(color),
        at: CGPoint(x: x, y: y))
    }
  }

  private func renderBands(
    _ context: GraphicsContext, size: CGSize, time: Double, levels: MusicWaveLevels?
  ) {
    let inset: CGFloat = 4
    let groupGap: CGFloat = 6
    let availableWidth = size.width - 2 * (inset + groupGap)
    guard availableWidth > 0, size.height > 6 else { return }
    let bass = levels?.bass ?? (0.46 + 0.22 * sin(time * 5))
    let midrange = levels?.midrange ?? (0.40 + 0.18 * sin(time * 4 - 1))
    let treble = levels?.treble ?? (0.35 + 0.14 * sin(time * 6 - 2))
    let bandLevels = [bass, midrange, treble]
    let groupWidth = availableWidth / CGFloat(bandLevels.count)
    let barsPerGroup = min(13, max(1, Int(groupWidth / 7)))
    let spacing = groupWidth / CGFloat(barsPerGroup)
    let width = min(3, spacing * 0.48)
    let baseline = size.height
    let maxHeight = size.height * 0.64
    let minHeight: CGFloat = 2

    for (band, energy) in bandLevels.enumerated() {
      let groupStart = inset + CGFloat(band) * (groupWidth + groupGap)
      for index in 0..<barsPerGroup {
        let position = Double(index) / Double(max(1, barsPerGroup - 1))
        let motion: Double
        if style == .shortLines {
          let phase = Double(index) * 2.4 + Double(band) * 1.7
          let speed = 4.5 + Double(index % 4) * 0.9
          motion = 0.5 + 0.5 * sin(phase - time * speed)
        } else {
          motion = 0.60 + 0.40 * sin(position * 6 - time * 6 + Double(band) * 2)
        }
        let strength = energy * motion
        let height = minHeight + (maxHeight - minHeight) * strength
        let x = groupStart + spacing * (CGFloat(index) + 0.5)
        let topY = baseline - height

        if style == .shortLines {
          let halfLength = min(2.5, spacing * 0.34)
          let segment = Path { path in
            path.move(to: CGPoint(x: x - halfLength, y: topY))
            path.addLine(to: CGPoint(x: x + halfLength, y: topY))
          }
          let bottomFade = min(1, strength / 0.14)
          let opacity = 0.52 * bottomFade * (1 - 0.65 * height / maxHeight)
          context.stroke(segment, with: .color(.white.opacity(opacity)), lineWidth: 1.25)
        } else {
          let baseColor = Color.white.opacity(0.16 + strength * 0.24)
          let shading = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [baseColor, .clear]),
            startPoint: CGPoint(x: x, y: baseline), endPoint: CGPoint(x: x, y: topY))
          let rect = CGRect(x: x - width / 2, y: topY, width: width, height: height)
          context.fill(Path(roundedRect: rect, cornerRadius: 0.65), with: shading)
        }
      }
    }
  }
}
