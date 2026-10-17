import IslandCore
// CodexBar MIT, 928166f899471bbdcb72210641cdec91324d0154.
import SwiftUI

struct UsageMenuCardHeaderView: View {
  let model: UsageMenuCardView.Model
  var planAction: (() -> Void)?
  @Environment(\.menuItemHighlighted) private var isHighlighted

  var body: some View {
    VStack(alignment: .leading, spacing: UsageMenuCardLayout.headerLineSpacing) {
      HStack(alignment: .firstTextBaseline, spacing: UsageMenuCardLayout.headerColumnSpacing) {
        Text(self.model.providerName).font(.headline)
          .fontWeight(.semibold)
          .lineLimit(1).truncationMode(.tail).layoutPriority(1)
        Spacer()
        Text(self.model.email).font(.subheadline)
          .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
          .lineLimit(1).truncationMode(.middle)
      }
      let liveSubtitle = self.liveSubtitle
      // Keep the geometry AppKit measured for this hosted row. A new error stays one line
      // until the next rebuild; a recovered error keeps its reserved height until then.
      let usesErrorLayout = self.model.subtitleStyle == .error
      let subtitleAlignment: VerticalAlignment = usesErrorLayout ? .top : .firstTextBaseline
      HStack(alignment: subtitleAlignment, spacing: UsageMenuCardLayout.headerColumnSpacing) {
        if usesErrorLayout {
          Text(self.model.subtitleText)
            .font(.footnote)
            .lineLimit(4)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 4)
            .hidden()
            .overlay(alignment: .topLeading) {
              Text(liveSubtitle.text)
                .font(.footnote)
                .foregroundStyle(self.subtitleColor(for: liveSubtitle.style))
                .lineLimit(4)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            .clipped()
            .layoutPriority(1)
        } else {
          Text(liveSubtitle.text)
            .font(.footnote)
            .foregroundStyle(self.subtitleColor(for: liveSubtitle.style))
            .lineLimit(1)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
        }
        Spacer()
        if usesErrorLayout {
          let showsCopyButton = liveSubtitle.style == .error && !liveSubtitle.text.isEmpty
          CopyIconButton(
            copyText: liveSubtitle.text,
            isHighlighted: self.isHighlighted,
            isInteractive: showsCopyButton
          )
          .opacity(showsCopyButton ? 1 : 0)
          .allowsHitTesting(showsCopyButton)
          .accessibilityHidden(!showsCopyButton)
        }
        if let plan = self.model.planText {
          Group {
            if let planAction {
              Button(action: planAction) {
                Text(plan)
              }
              .buttonStyle(.plain)
              .menuCardInteractiveControl()
              .accessibilityLabel(plan)
            } else {
              Text(plan)
            }
          }
          .font(.footnote)
          .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
          .lineLimit(1)
        }
      }
    }
  }

  private var liveSubtitle: MenuCardLiveSubtitle {
    let fallback = MenuCardLiveSubtitle(
      text: self.model.subtitleText, style: self.model.subtitleStyle)
    return fallback
  }

  private func subtitleColor(for style: UsageMenuCardView.Model.SubtitleStyle) -> Color {
    switch style {
    case .info: MenuHighlightStyle.secondary(self.isHighlighted)
    case .loading: MenuHighlightStyle.secondary(self.isHighlighted)
    case .error: MenuHighlightStyle.error(self.isHighlighted)
    }
  }
}

private struct CopyIconButtonStyle: ButtonStyle {
  let isHighlighted: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(4)
      .background {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
          .fill(
            MenuHighlightStyle.secondary(self.isHighlighted).opacity(
              configuration.isPressed ? 0.18 : 0))
      }
      .scaleEffect(configuration.isPressed ? 0.94 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

private struct CopyIconButton: View {
  let copyText: String
  let isHighlighted: Bool
  let isInteractive: Bool

  @State private var didCopy = false
  @State private var resetTask: Task<Void, Never>?

  var body: some View {
    Button {
      self.handleCopy()
    } label: {
      Image(systemName: self.didCopy ? "checkmark" : "doc.on.doc")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
        .frame(width: 18, height: 18)
    }
    .buttonStyle(CopyIconButtonStyle(isHighlighted: self.isHighlighted))
    .menuCardInteractiveControl(isEnabled: self.isInteractive)
    .accessibilityLabel(self.didCopy ? L("Copied") : L("Copy"))
    .onDisappear {
      self.resetTask?.cancel()
      self.resetTask = nil
    }
  }

  private func handleCopy() {
    let text = self.copyText
    self.resetTask?.cancel()
    MenuPasteboardCopy.perform(
      text,
      completion: {
        self.didCopy = true
        self.resetTask = Task { @MainActor in
          do {
            try await Task.sleep(for: .seconds(0.9))
          } catch {
            return
          }
          self.didCopy = false
          self.resetTask = nil
        }
      })
  }
}

/// Shared token-cost block (header, Today/window/metered/comparison lines, hint, error) used by
/// both the inline card body and the standalone cost section; only the value-line font differs.
struct TokenUsageSectionContent: View {
  let provider: Provider
  let tokenUsage: UsageMenuCardView.Model.TokenUsageSection
  let showsCodexHint: Bool
  let lineFont: Font
  @Environment(\.menuItemHighlighted) private var isHighlighted

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Text(UsageMenuCardView.Model.tokenUsageHeader(provider: self.provider))
          .font(.body)
          .fontWeight(.medium)
        if self.tokenUsage.isRefreshing {
          ProgressView()
            .controlSize(.mini)
            .accessibilityLabel(L("Refreshing"))
        }
      }
      Text(self.tokenUsage.sessionLine)
        .font(self.lineFont)
        .lineLimit(1)
      Text(self.tokenUsage.monthLine)
        .font(self.lineFont)
        .lineLimit(1)
      if let metered = self.tokenUsage.meteredLine, !metered.isEmpty {
        Text(metered)
          .font(self.lineFont)
          .lineLimit(1)
      }
      ForEach(self.tokenUsage.comparisonLines, id: \.self) { line in
        Text(line)
          .font(self.lineFont)
          .lineLimit(1)
      }
      if self.provider != .codex || self.showsCodexHint,
        let hint = self.tokenUsage.hintLine,
        !hint.isEmpty
      {
        Text(hint)
          .font(.footnote)
          .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
          .lineLimit(4)
          .fixedSize(horizontal: false, vertical: true)
      }
      if let error = self.tokenUsage.errorLine, !error.isEmpty {
        Text(error)
          .font(.footnote)
          .foregroundStyle(MenuHighlightStyle.error(self.isHighlighted))
          .lineLimit(4)
          .fixedSize(horizontal: false, vertical: true)
          .overlay {
            ClickToCopyOverlay(copyText: self.tokenUsage.errorCopyText ?? error)
          }
      }
    }
  }
}
