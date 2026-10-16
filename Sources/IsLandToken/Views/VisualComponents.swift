import AppKit
import Charts
import IslandCore
import SwiftUI

enum AppResourceBundle {
  static let bundle: Bundle =
    Bundle.main.resourceURL.flatMap {
      Bundle(url: $0.appendingPathComponent("IsLandToken_IsLandToken.bundle"))
    } ?? Bundle.module
}

extension Provider {
  var color: Color {
    Color(hex: defaultColorHex)
  }
}
extension Preferences {
  func providerColor(_ provider: Provider) -> Color { Color(hex: colorHex(for: provider)) }
}
extension Color {
  init(hex: String) {
    let value = Preferences.normalizedHex(hex)
    let hexValue = UInt64(value.dropFirst(), radix: 16) ?? 0x28B6A8
    self.init(
      red: Double((hexValue >> 16) & 0xFF) / 255,
      green: Double((hexValue >> 8) & 0xFF) / 255,
      blue: Double(hexValue & 0xFF) / 255)
  }
  var hexString: String {
    let color = NSColor(self).usingColorSpace(.sRGB) ?? .systemTeal
    return String(
      format: "#%02X%02X%02X", Int((color.redComponent * 255).rounded()),
      Int((color.greenComponent * 255).rounded()), Int((color.blueComponent * 255).rounded()))
  }
}
extension Accent {
  func color(for provider: Provider, preferences: Preferences? = nil) -> Color {
    switch self {
    case .provider: preferences?.providerColor(provider) ?? provider.color
    case .mint: .mint
    case .blue: .cyan
    case .purple: .purple
    case .orange: .orange
    case .white: .white
    }
  }
}

/// Compact vector mark shared by every UI entry point that represents the
/// Island. Its flared top shoulders and rounded lower body mirror the live
/// Island surface instead of using the generic SF Symbols capsule.
struct IslandIcon: Shape {
  static let menuBarImage: NSImage = {
    let size = NSSize(width: 22, height: 14)
    let image = NSImage(size: size)
    image.lockFocus()
    defer { image.unlockFocus() }
    // SwiftUI's Path uses a top-left origin, while NSImage drawing is
    // bottom-left based. Flip the context so this template matches the
    // orientation of the other Island icons.
    let context = NSGraphicsContext.current!.cgContext
    context.saveGState()
    context.translateBy(x: 0, y: size.height)
    context.scaleBy(x: 1, y: -1)
    defer { context.restoreGState() }
    let path = NSBezierPath(cgPath: IslandIcon().path(in: CGRect(origin: .zero, size: size)).cgPath)
    path.lineWidth = 1.6
    path.lineJoinStyle = .round
    path.lineCapStyle = .round
    NSColor.black.setStroke()
    path.stroke()
    image.isTemplate = true
    return image
  }()

  func path(in rect: CGRect) -> Path {
    let shoulderWidth = rect.width * 0.09
    let shoulderHeight = rect.height * 0.14
    let lowerRadius = rect.height * 0.29
    let left = rect.minX + shoulderWidth
    let right = rect.maxX - shoulderWidth
    let lowerEdge = rect.maxY - lowerRadius
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    path.addCurve(
      to: CGPoint(x: right, y: rect.minY + shoulderHeight),
      control1: CGPoint(x: rect.maxX - shoulderWidth * 0.2, y: rect.minY),
      control2: CGPoint(x: right, y: rect.minY + shoulderHeight * 0.55))
    path.addLine(to: CGPoint(x: right, y: lowerEdge))
    path.addQuadCurve(
      to: CGPoint(x: right - lowerRadius, y: rect.maxY),
      control: CGPoint(x: right, y: rect.maxY))
    path.addLine(to: CGPoint(x: left + lowerRadius, y: rect.maxY))
    path.addQuadCurve(
      to: CGPoint(x: left, y: lowerEdge),
      control: CGPoint(x: left, y: rect.maxY))
    path.addLine(to: CGPoint(x: left, y: rect.minY + shoulderHeight))
    path.addCurve(
      to: CGPoint(x: rect.minX, y: rect.minY),
      control1: CGPoint(x: left, y: rect.minY + shoulderHeight * 0.55),
      control2: CGPoint(x: rect.minX + shoulderWidth * 0.2, y: rect.minY))
    path.closeSubpath()
    return path
  }
}

struct ProviderIcon: View {
  let provider: Provider
  var size: CGFloat = 22
  var color: Color? = nil
  private static let images: [Provider: NSImage] = Dictionary(
    uniqueKeysWithValues: Provider.allCases.compactMap { provider in
      guard let url = AppResourceBundle.bundle.url(forResource: provider.rawValue, withExtension: "svg"),
        let image = NSImage(contentsOf: url)
      else { return nil }
      image.isTemplate = true
      return (provider, image)
    })
  var body: some View {
    Group {
      if let image = Self.images[provider] {
        Image(nsImage: image).resizable().scaledToFit()
      } else {
        Image(systemName: "sparkle").resizable().scaledToFit()
      }
    }
    .foregroundStyle(color ?? provider.color)
    .frame(width: size, height: size)
    .accessibilityLabel(provider.name)
  }
}

struct QuotaGauge: View {
  var value: Double?
  var style: ChartStyle
  var color: Color
  var samples: [Sample] = []
  var remaining = true
  var compact = false
  var body: some View {
    Group {
      switch style {
      case .ring:
        let lineWidth: CGFloat = compact ? 3 : 6
        let size: CGFloat = compact ? 20 : 78
        ZStack {
          Circle().strokeBorder(color.opacity(0.38), lineWidth: lineWidth)
          Circle().inset(by: lineWidth / 2).trim(from: 0, to: (value ?? 0) / 100).stroke(
            color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
          ).rotationEffect(.degrees(-90))
          if !compact {
            Text(label).font(.system(size: 23, weight: .semibold, design: .rounded))
              .monospacedDigit()
          }
        }.frame(width: size, height: size)
      case .number:
        Text(label).font(.system(size: compact ? 13 : 39, weight: .medium, design: .rounded))
          .monospacedDigit().foregroundStyle(color)
      case .bar:
        VStack(alignment: .leading, spacing: 10) {
          if !compact {
            Text(label).font(.system(size: 32, weight: .medium, design: .rounded)).monospacedDigit()
          }
          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              Capsule().fill(color.opacity(0.38))
              Capsule().fill(color).frame(width: geometry.size.width * (value ?? 0) / 100)
            }
          }.frame(height: compact ? 5 : 7)
        }.frame(width: compact ? 28 : 110)
      case .segments:
        VStack(alignment: .leading, spacing: 10) {
          if !compact {
            Text(label).font(.system(size: 32, weight: .medium, design: .rounded)).monospacedDigit()
          }
          HStack(spacing: compact ? 2 : 4) {
            ForEach(0..<10) { index in
              RoundedRectangle(cornerRadius: 2).fill(
                color.opacity(Double(index) < (value ?? 0) / 10 ? 1 : 0.38))
            }
          }.frame(width: compact ? 36 : 110, height: compact ? 12 : 19)
        }
      case .sparkline:
        VStack(alignment: .leading, spacing: 6) {
          if !compact {
            Text(label).font(.system(size: 30, weight: .medium, design: .rounded)).monospacedDigit()
          }
          if samples.count > 1 {
            Chart(samples) { sample in
              AreaMark(
                x: .value(T("时间"), sample.date),
                y: .value(T("额度"), remaining ? 100 - sample.used : sample.used)
              ).foregroundStyle(color.opacity(0.30))
              LineMark(
                x: .value(T("时间"), sample.date),
                y: .value(T("额度"), remaining ? 100 - sample.used : sample.used)
              ).foregroundStyle(color).interpolationMethod(.linear)
            }.chartPlotStyle { $0.background(color.opacity(0.14)) }.chartYScale(domain: 0...100)
              .chartXAxis(.hidden).chartYAxis(.hidden).frame(
                width: compact ? 30 : 110, height: compact ? 16 : 28)
          } else {
            Rectangle().fill(color.opacity(0.2)).frame(width: compact ? 30 : 110, height: 1)
            if !compact { Text(T("等待更多采样")).font(.caption2).foregroundStyle(.secondary) }
          }
        }
      }
    }.accessibilityLabel(value == nil ? T("额度未知") : T("%@ %@", T(remaining ? "剩余" : "已用"), label))
  }
  private var label: String { value.map { String(format: "%.0f%%", $0) } ?? "—" }
}

struct StatusDot: View {
  var good: Bool
  var body: some View { Circle().fill(good ? Color.mint : Color.orange).frame(width: 5, height: 5) }
}

struct ResetLabel: View {
  var window: QuotaWindow?
  var fontSize: CGFloat = 10
  var absolute = false
  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { timeline in
      Text(text(now: timeline.date)).font(.system(size: fontSize)).foregroundStyle(.secondary)
        .lineLimit(1)
    }
  }
  func text(now: Date) -> String {
    guard let reset = window?.resetsAt else { return T(window?.resetDescription ?? "未提供重置时间") }
    if absolute {
      let formatter = DateFormatter()
      formatter.locale = UserDefaults.standard.string(forKey: "interfaceLanguage") == InterfaceLanguage.english.rawValue
        ? Locale(identifier: "en_US") : Locale(identifier: "zh_CN")
      formatter.calendar = Calendar(identifier: .gregorian)
      formatter.timeZone = .current
      formatter.dateFormat = UserDefaults.standard.string(forKey: "interfaceLanguage") == InterfaceLanguage.english.rawValue
        ? "MMM d, HH:mm" : "'重置于 'MM月dd日 HH:mm"
      return formatter.string(from: reset)
    }
    let seconds = reset.timeIntervalSince(now)
    if seconds <= 0 { return T("等待刷新重置状态") }
    let hours = Int(seconds / 3600)
    let minutes = max(1, Int(seconds / 60) % 60)
    return hours >= 24
      ? T("%d 天 %d 小时后重置", hours / 24, hours % 24)
      : hours > 0 ? T("%d 小时 %d 分后重置", hours, minutes) : T("%d 分钟后重置", minutes)
  }
}

struct Surface<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      // `primary` adapts to both light and dark settings. The previous white
      // glass edge disappeared against a light translucent window background.
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(.primary.opacity(0.24), lineWidth: 1))
      .shadow(color: .primary.opacity(0.06), radius: 1, y: 1)
  }
}
