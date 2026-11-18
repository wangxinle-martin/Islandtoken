import Charts
import IslandCore
import SwiftUI

struct HistoryView: View {
  private enum Period: Int, CaseIterable {
    case hour = 1
    case day = 24
    case week = 168
    case month = 720
    case custom = 0

    var title: String {
      switch self {
      case .hour: T("近 1 小时")
      case .day: T("近 24 小时")
      case .week: T("近 7 天")
      case .month: T("近 30 天")
      case .custom: T("自定义")
      }
    }
  }

  @ObservedObject var store: AppStore
  let provider: Provider
  @Environment(\.calendar) private var calendar
  @State private var windowID = "primary"
  @State private var period = Period.day
  @State private var start = Date().addingTimeInterval(-24 * 3600)
  @State private var end = Date()

  var body: some View {
    VStack(spacing: 20) {
      Surface {
        VStack(alignment: .leading, spacing: 18) {
          Text(T("额度趋势")).font(.headline)
          VStack(alignment: .leading, spacing: 8) {
            Text(T("额度")).font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
              TileChoice(selection: $windowID, value: "primary") {
                Text(
                  UserFacingText.quotaTitle(
                    store.readings[provider]?.window("primary")?.title ?? "主要额度"))
              }
              ForEach(store.readings[provider]?.windows.filter { $0.id != "primary" } ?? []) {
                option in
                TileChoice(selection: $windowID, value: option.id) {
                  Text(UserFacingText.quotaTitle(option.title))
                }
              }
            }
          }
          timeFilter
          if period == .custom {
            trend(in: customRange)
          } else {
            TimelineView(.periodic(from: .now, by: 60)) { _ in
              let now = Date()
              trend(in: now.addingTimeInterval(-Double(period.rawValue) * 3600)..<now)
            }
          }
          HStack {
            Text(T("本地保留近 30 天的采样")).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button(T("导出 CSV")) { store.exportHistory() }
          }
        }
      }
      Surface {
        VStack(alignment: .leading, spacing: 16) {
          HStack {
            Text(T("Token 与费用")).font(.headline)
            Spacer()
          }
          Text(T("本地额度采集不读取 Token 与费用记录；缺失值显示 —。")).font(.caption)
            .foregroundStyle(.secondary)
          let cost = store.demoMode ? nil : store.costs[provider]
          HStack(spacing: 25) {
            metric(T("今日 Token"), value: cost?.sessionTokens.map { $0.formatted() })
            metric(T("今日估算 USD"), value: cost?.sessionCostUSD.map { String(format: "$%.2f", $0) })
            metric(T("近 30 天 Token"), value: cost?.last30DaysTokens.map { $0.formatted() })
            metric(T("近 30 天 USD"), value: cost?.last30DaysCostUSD.map { String(format: "$%.2f", $0) })
          }
          if let error = store.costErrors[provider], !store.demoMode {
            Text(UserFacingText.value(error)).font(.caption).foregroundStyle(.orange)
          }
          if let daily = cost?.daily, !daily.isEmpty {
            Chart(daily.suffix(30)) { day in
              if let tokens = day.totalTokens {
                BarMark(x: .value(T("日期"), day.date), y: .value("Token", tokens)).foregroundStyle(
                  store.preferences.providerColor(provider).opacity(0.75))
              }
            }.chartXAxis(.hidden).frame(height: 85)
          }
        }
      }
    }
    .onAppear(perform: selectAvailableWindow)
    .onChange(of: provider) { _, _ in
      selectAvailableWindow()
    }
    .onChange(of: store.readings[provider]?.windows.map(\.id) ?? []) { _, _ in
      selectAvailableWindow()
    }
  }

  private var timeFilter: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(T("时间范围")).font(.caption).foregroundStyle(.secondary)
      Picker(T("时间范围"), selection: $period) {
        ForEach(Period.allCases, id: \.self) { option in
          Text(option.title).tag(option)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      if period == .custom {
        VStack(alignment: .leading, spacing: 8) {
          DatePicker(T("开始时间"), selection: $start, displayedComponents: [.date, .hourAndMinute])
          DatePicker(T("结束时间"), selection: $end, displayedComponents: [.date, .hourAndMinute])
        }
        .controlSize(.small)
      }
    }
  }

  private var customRange: Range<Date>? {
    guard let startMinute = calendar.dateInterval(of: .minute, for: start),
      let endMinute = calendar.dateInterval(of: .minute, for: end),
      startMinute.start < endMinute.end
    else { return nil }
    return startMinute.start..<endMinute.end
  }

  @ViewBuilder
  private func trend(in range: Range<Date>?) -> some View {
    if let range {
      let data = store.history(provider: provider, windowID: windowID, in: range)
      if data.isEmpty {
        ContentUnavailableView(
          T("该时间范围内暂无采样"), systemImage: "chart.xyaxis.line",
          description: Text(T("请选择其他时间范围。"))
        ).frame(height: 190)
      } else {
        let color = store.preferences.providerColor(provider)
        Chart(data) { sample in
          let x = PlottableValue.value(T("时间"), sample.date)
          let y = PlottableValue.value(
            T("额度 %"), store.preferences.remaining ? 100 - sample.used : sample.used)
          if data.count == 1 {
            PointMark(x: x, y: y).foregroundStyle(color)
          } else {
            AreaMark(x: x, y: y).foregroundStyle(
              LinearGradient(colors: [color.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
            LineMark(x: x, y: y).foregroundStyle(color)
          }
        }
        .chartXScale(domain: range.lowerBound...range.upperBound)
        .chartYScale(domain: 0...100)
        .frame(height: 190)
      }
    } else {
      ContentUnavailableView(
        T("时间范围无效"), systemImage: "calendar.badge.exclamationmark",
        description: Text(T("结束时间须等于或晚于开始时间。"))
      ).frame(height: 190)
    }
  }

  private func selectAvailableWindow() {
    let windows = store.readings[provider]?.windows ?? []
    guard !windows.isEmpty else {
      windowID = "primary"
      return
    }
    guard !windows.contains(where: { $0.id == windowID }) else { return }
    windowID = windows.first(where: { $0.id == "primary" })?.id ?? windows[0].id
  }

  private func metric(_ title: String, value: String?) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.system(size: 9)).foregroundStyle(.secondary)
      Text(value ?? "—").font(.system(size: 17, weight: .medium, design: .rounded))
        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
}
