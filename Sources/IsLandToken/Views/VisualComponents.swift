import Charts
import IslandCore
import SwiftUI

extension Provider {
  var color: Color {
    switch self {
    case .codex: Color(red: 0.42, green: 0.90, blue: 0.75)
    case .claude: Color(red: 0.91, green: 0.62, blue: 0.46)
    case .antigravity: Color(red: 0.53, green: 0.69, blue: 1)
    case .gemini: .purple
    case .copilot, .kiro: .indigo
    case .deepseek, .openrouter: .blue
    default: .teal
    }
  }
}
extension Accent {
  func color(for provider: Provider) -> Color {
    switch self {
    case .provider: provider.color
    case .mint: .mint
    case .blue: .cyan
    case .purple: .purple
    case .orange: .orange
    case .white: .white
    }
  }
}

struct ProviderIcon: View {
  let provider: Provider
  var size: CGFloat = 22
  var color: Color? = nil
  private static let images: [Provider: NSImage] = Dictionary(
    uniqueKeysWithValues: Provider.allCases.compactMap { provider in
      let resources =
        Bundle.main.resourceURL.flatMap {
          Bundle(url: $0.appendingPathComponent("IsLandToken_IsLandToken.bundle"))
        } ?? Bundle.module
      guard let url = resources.url(forResource: provider.rawValue, withExtension: "svg"),
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
                x: .value("时间", sample.date),
                y: .value("额度", remaining ? 100 - sample.used : sample.used)
              ).foregroundStyle(color.opacity(0.30))
              LineMark(
                x: .value("时间", sample.date),
                y: .value("额度", remaining ? 100 - sample.used : sample.used)
              ).foregroundStyle(color).interpolationMethod(.linear)
            }.chartPlotStyle { $0.background(color.opacity(0.14)) }.chartYScale(domain: 0...100)
              .chartXAxis(.hidden).chartYAxis(.hidden).frame(
                width: compact ? 30 : 110, height: compact ? 16 : 28)
          } else {
            Rectangle().fill(color.opacity(0.2)).frame(width: compact ? 30 : 110, height: 1)
            if !compact { Text("等待更多采样").font(.caption2).foregroundStyle(.secondary) }
          }
        }
      }
    }.accessibilityLabel(value == nil ? "额度未知" : "\(remaining ? "剩余" : "已用") \(label)")
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
    guard let reset = window?.resetsAt else { return window?.resetDescription ?? "未提供重置时间" }
    if absolute {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.calendar = Calendar(identifier: .gregorian)
      formatter.timeZone = .current
      formatter.dateFormat = "'重置于 'MM月dd日 HH:mm"
      return formatter.string(from: reset)
    }
    let seconds = reset.timeIntervalSince(now)
    if seconds <= 0 { return "等待刷新重置状态" }
    let hours = Int(seconds / 3600)
    let minutes = max(1, Int(seconds / 60) % 60)
    return hours >= 24
      ? "\(hours / 24) 天 \(hours % 24) 小时后重置"
      : hours > 0 ? "\(hours) 小时 \(minutes) 分后重置" : "\(minutes) 分钟后重置"
  }
}

struct Surface<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
      .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
      .overlay(RoundedRectangle(cornerRadius: 16).stroke(.primary.opacity(0.065), lineWidth: 1))
  }
}
