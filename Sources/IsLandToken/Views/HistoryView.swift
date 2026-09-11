import Charts
import IslandCore
import SwiftUI

struct HistoryView: View {
  @ObservedObject var store: AppStore
  @State private var provider: Provider = .codex
  @State private var windowID = "primary"
  var body: some View {
    VStack(spacing: 20) {
      Surface {
        VStack(alignment: .leading, spacing: 18) {
          HStack {
            Text("额度趋势").font(.headline)
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
              Text("平台").font(.caption).foregroundStyle(.secondary)
              LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
                ForEach(store.preferences.providersToFetch) { option in
                  TileChoice(selection: $provider, value: option) { Text(option.name) }
                }
              }
            }.frame(maxWidth: .infinity)
              .onChange(of: provider) { _, _ in windowID = "primary" }
            VStack(alignment: .leading, spacing: 8) {
              Text("额度").font(.caption).foregroundStyle(.secondary)
              LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 6)], spacing: 6) {
                TileChoice(selection: $windowID, value: "primary") {
                  Text(store.readings[provider]?.window("primary")?.title ?? "主要额度")
                }
                ForEach(store.readings[provider]?.windows.filter { $0.id != "primary" } ?? []) {
                  option in
                  TileChoice(selection: $windowID, value: option.id) { Text(option.title) }
                }
              }
            }.frame(maxWidth: .infinity)
          }
          let data = store.history(provider: provider, windowID: windowID)
          if data.count > 1 {
            Chart(data) { sample in
              AreaMark(
                x: .value("时间", sample.date),
                y: .value("额度 %", store.preferences.remaining ? 100 - sample.used : sample.used)
              ).foregroundStyle(
                LinearGradient(
                  colors: [provider.color.opacity(0.25), .clear], startPoint: .top,
                  endPoint: .bottom))
              LineMark(
                x: .value("时间", sample.date),
                y: .value("额度 %", store.preferences.remaining ? 100 - sample.used : sample.used)
              ).foregroundStyle(provider.color)
            }.chartYScale(domain: 0...100).frame(height: 190)
          } else {
            ContentUnavailableView(
              "等待更多采样", systemImage: "chart.xyaxis.line",
              description: Text("保持 App 运行，第二次成功同步后即可看到趋势。")
            ).frame(height: 190)
          }
          HStack {
            Text("最多展示最近 144 次采样 · 本地保留 30 天").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("导出 CSV") { store.exportHistory() }
          }
        }
      }
      Surface {
        VStack(alignment: .leading, spacing: 16) {
          HStack {
            Text("Token 与费用").font(.headline)
            Spacer()
            Button(store.refreshingCost ? "读取中…" : "读取费用记录") { Task { await store.refreshCosts() } }
              .disabled(store.refreshingCost || store.demoMode)
          }
          Text("这里显示已消耗的 Token 与估算费用，不表示剩余订阅额度。费用由 CodexBar 根据平台或本地会话记录计算；缺失值显示 —。").font(.caption)
            .foregroundStyle(.secondary)
          ForEach(store.preferences.providersToFetch.filter(\.supportsCost)) { provider in
            VStack(alignment: .leading, spacing: 12) {
              HStack {
                ProviderIcon(provider: provider, size: 18)
                Text(provider.name).font(.subheadline.weight(.semibold))
                Spacer()
              }
              let cost = store.demoMode ? nil : store.costs[provider]
              HStack(spacing: 25) {
                metric("今日 Token", value: cost?.sessionTokens.map { $0.formatted() })
                metric("今日估算 USD", value: cost?.sessionCostUSD.map { String(format: "$%.2f", $0) })
                metric("近 30 天 Token", value: cost?.last30DaysTokens.map { $0.formatted() })
                metric(
                  "近 30 天 USD", value: cost?.last30DaysCostUSD.map { String(format: "$%.2f", $0) })
              }
              if let error = store.costErrors[provider], !store.demoMode {
                Text(error).font(.caption).foregroundStyle(.orange)
              }
              if let daily = cost?.daily, !daily.isEmpty {
                Chart(daily.suffix(30)) { day in
                  if let tokens = day.totalTokens {
                    BarMark(x: .value("日期", day.date), y: .value("Token", tokens)).foregroundStyle(
                      provider.color.opacity(0.75))
                  }
                }.chartXAxis(.hidden).frame(height: 85)
              }
              Divider()
            }.padding(.top, 8)
          }
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
