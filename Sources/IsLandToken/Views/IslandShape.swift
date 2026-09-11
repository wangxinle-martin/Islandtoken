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

struct IslandRefreshSweep: View {
  @State private var startedAt = Date()
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
      let cycle: Double =
        reduceMotion
        ? 0.62
        : max(0, timeline.date.timeIntervalSince(startedAt)).truncatingRemainder(dividingBy: 2.05)
      let scanDuration: Double = 1.18
      let progress = min(1, cycle / scanDuration)
      let phase: CGFloat = CGFloat(reduceMotion ? 0.5 : progress * progress)
      let scanActive = reduceMotion || cycle < scanDuration
      GeometryReader { geometry in
        let x = geometry.size.width * phase
        let beamWidth = max(16, geometry.size.width * 0.14)
        ZStack(alignment: .leading) {
          LinearGradient(
            colors: [
              .clear, .cyan.opacity(0.12), .mint.opacity(0.26), .cyan.opacity(0.12), .clear,
            ], startPoint: .leading, endPoint: .trailing
          )
          .frame(width: beamWidth)
          .blur(radius: 4)
          .offset(x: x - beamWidth * 0.5)
          Rectangle()
            .fill(Color.mint.opacity(0.42))
            .frame(width: 1, height: geometry.size.height * 0.55)
            .shadow(color: .cyan.opacity(0.35), radius: 3)
            .offset(x: x)
        }
        .opacity(scanActive ? 1 : 0)
      }
    }.allowsHitTesting(false).accessibilityHidden(true)
  }
}

struct RefreshSymbol: View {
  var active: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !active || reduceMotion)) {
      timeline in
      Image(systemName: "arrow.clockwise")
        .rotationEffect(
          .degrees(
            active && !reduceMotion
              ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
                * 360 : 0))
    }.accessibilityHidden(true)
  }
}

struct DigitFlipText: View {
  let text: String
  let active: Bool
  let color: Color
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !active || reduceMotion)) {
      timeline in
      let phase =
        active && !reduceMotion
        ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.82) / 0.82
        : 0
      HStack(spacing: 0) {
        ForEach(Array(text.enumerated()), id: \.offset) { _, character in
          let eased = (1 - cos(phase * .pi)) / 2
          Text(String(character))
            .rotation3DEffect(
              .degrees(character.isNumber ? eased * 360 : 0),
              axis: (x: 1, y: 0, z: 0), perspective: 0.42)
        }
      }
      .font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
      .foregroundStyle(color)
      .frame(height: 16).clipped()
    }
    .lineLimit(1).minimumScaleFactor(0.75)
  }
}

struct IslandRefreshMeteor: View {
  @State private var startedAt = Date()
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
        let x = (geometry.size.width + 60) * CGFloat(reduceMotion ? 0.5 : progress * progress) - 30
        let y = geometry.size.height * (expanded ? 0.22 : 0.5)
        ZStack(alignment: .topLeading) {
          Capsule()
            .fill(
              LinearGradient(
                colors: [.clear, .cyan.opacity(0.12), .white.opacity(0.55)], startPoint: .leading,
                endPoint: .trailing)
            )
            .frame(width: 30, height: 1)
            .rotationEffect(.degrees(-12))
            .offset(x: x - 18, y: y + 3)
            .blur(radius: 1.2)
          Circle()
            .fill(Color.white.opacity(0.9))
            .frame(width: 2.5, height: 2.5)
            .shadow(color: .cyan.opacity(0.85), radius: 5)
            .offset(x: x, y: y)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .opacity(reduceMotion || cycle < 0.75 ? 1 : 0)
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
      let pulse = reduceMotion ? 0.5 : (sin(time * 4.2) + 1) / 2
      let colorPhase = (sin(time * 1.7) + 1) / 2
      // Deliberately span cyan-green to magenta-red for a high-contrast status pulse.
      let glowColor = Color(hue: 0.48 + colorPhase * 0.42, saturation: 0.96, brightness: 1.0)
      IslandLowerEdge(expanded: expanded)
        // Blur the stroke before applying the shadow so the island interior stays dark.
        .stroke(glowColor.opacity(0.30 + pulse * 0.58), lineWidth: 1.1)
        .blur(radius: 4 + pulse * 5)
        .shadow(color: glowColor.opacity(0.34 + pulse * 0.58), radius: 10 + pulse * 16)
        .shadow(color: glowColor.opacity(0.20 + pulse * 0.34), radius: 24 + pulse * 26)
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
