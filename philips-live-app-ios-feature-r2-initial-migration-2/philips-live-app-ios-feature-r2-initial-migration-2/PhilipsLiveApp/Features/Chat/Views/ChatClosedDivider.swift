import Filament
import SwiftUI

struct ChatClosedDivider: View {
    @EnvironmentObject private var themeManager: DlsThemeManager
    @Environment(\.locale) private var locale

    let closedAt: Date

    /// Design: short edge lines (75pt) with the label centered between them, not lines running up to the text.
    private let lineMaxWidth: CGFloat = 75

    var body: some View {
        let dimensions = themeManager.current.dimensionTokens
        let time = closedAt.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
        let date = closedAt.formatted(Date.FormatStyle(date: .numeric, time: .omitted).locale(locale))
        let prefix = L10n.string("ChatScreen.chatClosedAt").trimmingCharacters(in: .whitespaces)
        let label = "\(prefix) \(time) \(date)"
        HStack(spacing: 0) {
            edgeLine
            Spacer(minLength: dimensions.size03)
            DlsText(
                label,
                token: themeManager.current.fontTokens.referenceM_Book,
                foregroundStyle: themeManager.current.colorTokens.foreground.color.secondary
            )
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, dimensions.size03)
            .padding(.vertical, dimensions.size02)
            .layoutPriority(1)
            Spacer(minLength: dimensions.size03)
            edgeLine
        }
        .accessibilityElement(children: .combine)
    }

    /// `DlsDivider` wraps SwiftUI's `Divider`, which turns vertical inside an `HStack`; `VStack` keeps it horizontal.
    private var edgeLine: some View {
        VStack {
            DlsDivider()
        }
        .frame(maxWidth: lineMaxWidth)
    }
}
