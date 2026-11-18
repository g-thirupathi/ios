import Filament
import SwiftUI

/// Filament has no top-bar view, and the system navigation bar turns into glass capsules on iOS 26, so this draws
/// Figma's bar: a back button, the centred title and a three-dots button, above a divider.
struct ChatHeader: View {
    @EnvironmentObject private var themeManager: DlsThemeManager

    let showsMenu: Bool
    let onBack: () -> Void
    let onMore: () -> Void

    var body: some View {
        let dimensions = themeManager.current.dimensionTokens
        VStack(spacing: 0) {
            HStack(spacing: dimensions.size05) {
                // Both sides hold a same-sized button, so the title stays centred.
                ZStack(alignment: .leading) {
                    moreButton.hidden()
                    backButton
                }
                DlsText(
                    L10n.string("ChatScreen.chat_with_agent"),
                    token: themeManager.current.fontTokens.bodyM_Bold
                )
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
                ZStack(alignment: .trailing) {
                    backButton.hidden()
                    if showsMenu {
                        moreButton
                    } else {
                        moreButton.hidden()
                    }
                }
            }
            .padding(.horizontal, dimensions.size07)
            .padding(.bottom, dimensions.size05)
            DlsDivider()
        }
    }

    private var backButton: some View {
        DlsButton("", variant: .Quiet, icon: DlsAsset.chevronLeft, action: onBack)
            .accessibilityLabel(Text(verbatim: L10n.string("DisclaimerScreen.back")))
    }

    private var moreButton: some View {
        DlsButton("", variant: .Quiet, icon: DlsAsset("ThreeDotsHorizontal"), action: onMore)
    }
}
