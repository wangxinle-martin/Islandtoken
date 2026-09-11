// CodexBar MIT, 928166f899471bbdcb72210641cdec91324d0154.
import SwiftUI

struct CodexResetCreditPresentationItem: Equatable {
  let expiryText: String
  let compactExpiryText: String
}

struct CodexResetCreditsPresentation: Equatable {
  let text: String
  let items: [CodexResetCreditPresentationItem]

  var expirySummaryText: String {
    let visibleItems = self.items.prefix(4).map(\.compactExpiryText)
    let hiddenCount = self.items.count - visibleItems.count
    let suffix = hiddenCount > 0 ? ["+\(hiddenCount)"] : []
    return (visibleItems + suffix).joined(separator: " · ")
  }

  var helpText: String {
    self.items.enumerated().map { index, item in
      "\(index + 1). \(item.expiryText)"
    }.joined(separator: "\n")
  }

  var accessibilityLabel: String {
    [L("Limit Reset Credits"), self.text, self.helpText]
      .filter { !$0.isEmpty }
      .joined(separator: ", ")
  }

}

struct CodexResetCreditsContent: View {
  let presentation: CodexResetCreditsPresentation
  @Environment(\.menuItemHighlighted) private var isHighlighted

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(L("Limit Reset Credits"))
        .font(.body)
        .fontWeight(.medium)
        .lineLimit(1)
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(self.presentation.text)
          .font(.footnote.weight(.semibold))
          .foregroundStyle(MenuHighlightStyle.primary(self.isHighlighted))
          .lineLimit(1)
          .layoutPriority(1)
        Spacer(minLength: 8)
        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Image(systemName: "clock")
            .font(.caption2)
          Text(self.presentation.expirySummaryText)
            .font(.caption)
            .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
        .accessibilityHidden(true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .help(self.presentation.helpText)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(self.presentation.accessibilityLabel)
  }
}
