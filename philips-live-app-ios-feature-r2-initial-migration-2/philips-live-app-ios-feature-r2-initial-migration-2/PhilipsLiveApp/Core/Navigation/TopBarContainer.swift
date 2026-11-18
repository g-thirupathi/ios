import Filament
import SwiftUI

/// A screen with Figma's top bar (optional centred title and a divider) instead of the system navigation bar, which
/// turns into glass capsules on iOS 26. Pushed on the navigation stack it leads with a back button; presented in a
/// sheet (`isModal`) it has a close button in the same place.
struct TopBarContainer<Content: View>: View {
    @EnvironmentObject private var themeManager: DlsThemeManager
    @Environment(\.dismiss) private var dismiss

    let titleKey: String?
    var isModal = false
    let backLabelKey: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            topBar
            content
        }
        .background { themeManager.current.colorTokens.container.background.primary.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .swipeBackEnabled()
    }

    private var leadingIcon: DlsAsset {
        isModal ? DlsAsset.cross : DlsAsset.chevronLeft
    }

    private var topBar: some View {
        let dimensions = themeManager.current.dimensionTokens
        return VStack(spacing: 0) {
            ZStack {
                if let titleKey {
                    DlsText(L10n.string(titleKey), token: themeManager.current.fontTokens.bodyM_Bold)
                        .lineLimit(1)
                        .padding(.horizontal, dimensions.size21)
                        .accessibilityAddTraits(.isHeader)
                }
                HStack {
                    DlsButton("", variant: .Quiet, icon: leadingIcon) { dismiss() }
                        .accessibilityLabel(Text(verbatim: L10n.string(backLabelKey)))
                    Spacer()
                }
            }
            .padding(.horizontal, dimensions.size07)
            .padding(.top, isModal ? dimensions.size07 : 0)
            .padding(.bottom, dimensions.size05)
            DlsDivider()
        }
    }
}
