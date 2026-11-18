import Filament
import SwiftUI

struct DisclaimerSection: View {
    @EnvironmentObject private var themeManager: DlsThemeManager

    var titleKey: String?
    let bodyKey: String

    var body: some View {
        let theme = themeManager.current
        let secondary = theme.colorTokens.foreground.color.secondary
        VStack(alignment: .leading, spacing: theme.dimensionTokens.size05) {
            if let titleKey {
                DlsText(
                    L10n.string(titleKey),
                    token: theme.fontTokens.bodyS_Book,
                    foregroundStyle: theme.colorTokens.foreground.color.primary
                )
                .accessibilityAddTraits(.isHeader)
            }
            HStack(spacing: theme.dimensionTokens.size06) {
                DlsIcon(.operatorsManualISO, size: .large)
                DlsIcon(.warning, size: .medium)
            }
            .foregroundStyle(secondary)
            DlsText(L10n.string(bodyKey), token: theme.fontTokens.referenceS_Book, foregroundStyle: secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
