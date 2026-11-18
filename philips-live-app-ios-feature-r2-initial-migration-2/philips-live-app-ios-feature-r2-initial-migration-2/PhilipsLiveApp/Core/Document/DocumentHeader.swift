import Filament
import SwiftUI

/// A page's large title. It takes Filament's largest heading and steps down to the one two sizes below when the title
/// does not fit on one line; only at that smallest size does it wrap.
struct DocumentHeader: View {
    @EnvironmentObject private var themeManager: DlsThemeManager

    let titleKey: String

    var body: some View {
        let tokens = themeManager.current.fontTokens
        ViewThatFits(in: .horizontal) {
            singleLine(tokens.headingL_Bold)
            singleLine(tokens.headingM_Bold)
            text(tokens.headingS_Bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }

    private func singleLine(_ token: DlsFontToken) -> some View {
        text(token)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func text(_ token: DlsFontToken) -> some View {
        DlsText(
            L10n.string(titleKey),
            token: token,
            foregroundStyle: themeManager.current.colorTokens.foreground.color.primary
        )
    }
}
