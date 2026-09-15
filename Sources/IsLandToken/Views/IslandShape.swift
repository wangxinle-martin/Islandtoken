import IslandCore
import SwiftUI

/// The top edge flares outward into the screen edge; bottom corners remain convex.
/// Shared by rendering and mouse hit testing so transparent shoulders pass clicks through.
struct IslandShape: Shape {
  var expanded: Bool
  func path(in rect: CGRect) -> Path {
    let shoulder = min(12.0, rect.height / 3)
    let bottom = min(expanded ? 24.0 : 12.0, (rect.height - shoulder) / 2)
    let left = rect.minX + shoulder
    let right = rect.maxX - shoulder
    let top = rect.minY
    let base = rect.maxY
    let k = 0.5522847498
    var p = Path()
    p.move(to: CGPoint(x: rect.minX, y: top))
    p.addLine(to: CGPoint(x: rect.maxX, y: top))
    p.addCurve(
      to: CGPoint(x: right, y: top + shoulder),
      control1: CGPoint(x: rect.maxX - shoulder * k, y: top),
      control2: CGPoint(x: right, y: top + shoulder * (1 - k)))
    p.addLine(to: CGPoint(x: right, y: base - bottom))
    p.addQuadCurve(to: CGPoint(x: right - bottom, y: base), control: CGPoint(x: right, y: base))
    p.addLine(to: CGPoint(x: left + bottom, y: base))
    p.addQuadCurve(to: CGPoint(x: left, y: base - bottom), control: CGPoint(x: left, y: base))
    p.addLine(to: CGPoint(x: left, y: top + shoulder))
    p.addCurve(
      to: CGPoint(x: rect.minX, y: top), control1: CGPoint(x: left, y: top + shoulder * (1 - k)),
      control2: CGPoint(x: rect.minX + shoulder * k, y: top))
    p.closeSubpath()
    return p
  }
}

/// Open outline: never draws the horizontal edge that meets the physical notch.
struct IslandLowerEdge: Shape {
  var expanded: Bool
  func path(in rect: CGRect) -> Path {
    let shoulder = min(12.0, rect.height / 3)
    let bottom = min(expanded ? 24.0 : 12.0, (rect.height - shoulder) / 2)
    let left = rect.minX + shoulder
    let right = rect.maxX - shoulder
    let k = 0.5522847498
    var p = Path()
    p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
    p.addCurve(
      to: CGPoint(x: right, y: rect.minY + shoulder),
      control1: CGPoint(x: rect.maxX - shoulder * k, y: rect.minY),
      control2: CGPoint(x: right, y: rect.minY + shoulder * (1 - k)))
    p.addLine(to: CGPoint(x: right, y: rect.maxY - bottom))
    p.addQuadCurve(
      to: CGPoint(x: right - bottom, y: rect.maxY), control: CGPoint(x: right, y: rect.maxY))
    p.addLine(to: CGPoint(x: left + bottom, y: rect.maxY))
    p.addQuadCurve(
      to: CGPoint(x: left, y: rect.maxY - bottom), control: CGPoint(x: left, y: rect.maxY))
    p.addLine(to: CGPoint(x: left, y: rect.minY + shoulder))
    p.addCurve(
      to: CGPoint(x: rect.minX, y: rect.minY),
      control1: CGPoint(x: left, y: rect.minY + shoulder * (1 - k)),
      control2: CGPoint(x: rect.minX + shoulder * k, y: rect.minY))
    return p
  }
}

struct DigitFlipText: View {
  let text: String
  let active: Bool
  let color: Color
  var body: some View {
    HStack(spacing: 0) {
      ForEach(Array(text.enumerated()), id: \.offset) { index, character in
        if let digit = character.wholeNumberValue {
          RollingDigit(digit: digit, index: index, active: active)
        } else {
          Text(String(character))
        }
      }
    }
    .font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
    .foregroundStyle(color)
    .frame(height: 16)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(text)
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
    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
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
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
      let time = timeline.date.timeIntervalSinceReferenceDate
      let pulse = reduceMotion ? 0.5 : (sin(time * 6.3) + 1) / 2
      let colorPhase = (sin(time * 1.7) + 1) / 2
      // Deliberately span cyan-green to magenta-red for a high-contrast status pulse.
      let glowColor = Color(hue: 0.48 + colorPhase * 0.42, saturation: 0.96, brightness: 1.0)
      IslandLowerEdge(expanded: expanded)
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
    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
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
    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
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
