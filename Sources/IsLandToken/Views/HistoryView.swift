import Charts
import IslandCore
import SwiftUI

struct HistoryView: View {
  @ObservedObject var store: AppStore
  let provider: Provider
  @State private var windowID = "primary"
  var body: some View {
    VStack(spacing: 20) {
      Surface {
        VStack(alignment: .leading, spacing: 18) {
          Text(T("额度趋势")).font(.headline)
          VStack(alignment: .leading, spacing: 8) {
            Text(T("额度")).font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
              TileChoice(selection: $windowID, value: "primary") {
                Text(store.readings[provider]?.window("primary")?.title ?? T("主要额度"))
              }
              ForEach(store.readings[provider]?.windows.filter { $0.id != "primary" } ?? []) {
                option in
                TileChoice(selection: $windowID, value: option.id) { Text(option.title) }
              }
            }
          }
          let data = store.history(provider: provider, windowID: windowID)
          if data.count > 1 {
            Chart(data) { sample in
              AreaMark(
                x: .value(T("时间"), sample.date),
                y: .value(T("额度 %"), store.preferences.remaining ? 100 - sample.used : sample.used)
              ).foregroundStyle(
                LinearGradient(
                  colors: [store.preferences.providerColor(provider).opacity(0.25), .clear], startPoint: .top,
                  endPoint: .bottom))
              LineMark(
                x: .value(T("时间"), sample.date),
                y: .value(T("额度 %"), store.preferences.remaining ? 100 - sample.used : sample.used)
              ).foregroundStyle(store.preferences.providerColor(provider))
            }.chartYScale(domain: 0...100).frame(height: 190)
          } else {
            ContentUnavailableView(
              T("等待更多采样"), systemImage: "chart.xyaxis.line",
              description: Text(T("保持 App 运行，第二次成功同步后即可看到趋势。"))
            ).frame(height: 190)
          }
          HStack {
            Text(T("最多展示最近 144 次采样 · 本地保留 30 天")).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button(T("导出 CSV")) { store.exportHistory() }
          }
        }
      }
      if provider.supportsCost {
        Surface {
        VStack(alignment: .leading, spacing: 16) {
          HStack {
            Text(T("Token 与费用")).font(.headline)
            Spacer()
            Button(store.refreshingCost ? T("读取中…") : T("读取费用记录")) {
              Task { await store.refreshCost(for: provider) }
            }
              .disabled(store.refreshingCost || store.demoMode)
          }
          Text(T("这里显示已消耗的 Token 与估算费用，不表示剩余订阅额度。费用由 CodexBar 根据平台或本地会话记录计算；缺失值显示 —。")).font(.caption)
            .foregroundStyle(.secondary)
          let cost = store.demoMode ? nil : store.costs[provider]
          HStack(spacing: 25) {
            metric(T("今日 Token"), value: cost?.sessionTokens.map { $0.formatted() })
            metric(T("今日估算 USD"), value: cost?.sessionCostUSD.map { String(format: "$%.2f", $0) })
            metric(T("近 30 天 Token"), value: cost?.last30DaysTokens.map { $0.formatted() })
            metric(T("近 30 天 USD"), value: cost?.last30DaysCostUSD.map { String(format: "$%.2f", $0) })
          }
          if let error = store.costErrors[provider], !store.demoMode {
            Text(error).font(.caption).foregroundStyle(.orange)
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
      } else {
        Surface {
          Label(T("此提供商当前未提供 Token 与费用数据。"), systemImage: "info.circle")
            .font(.caption).foregroundStyle(.secondary)
        }
      }
    }
  }
  private func metric(_ title: String, value: String?) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.system(size: 9)).foregroundStyle(.secondary)
      Text(value ?? "—").font(.system(size: 17, weight: .medium, design: .rounded))
        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
}
