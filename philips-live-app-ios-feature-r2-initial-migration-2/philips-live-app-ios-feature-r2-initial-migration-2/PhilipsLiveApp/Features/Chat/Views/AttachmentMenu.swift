import Filament
import SwiftUI

struct AttachmentMenu: View {
    @EnvironmentObject private var themeManager: DlsThemeManager
    @State private var selection: ChatViewModel.AttachmentAction?

    /// The widest the menu may become; wider labels are truncated.
    let maxWidth: CGFloat
    let onSelect: (ChatViewModel.AttachmentAction) -> Void

    private let maxHeight: CGFloat = 320

    /// 168pt by default, growing with its labels up to `maxWidth`, past which labels truncate.
    var body: some View {
        DlsMenu(
            items: ChatViewModel.AttachmentAction.allCases,
            selection: $selection,
            maxHeight: maxHeight,
            onSelect: {
                guard let action = selection else { return }
                selection = nil
                onSelect(action)
            },
            content: { action in
                HStack(spacing: themeManager.current.dimensionTokens.size05) {
                    DlsIcon(action.icon, size: .medium)
                    CappedWidthLayout(maxWidth: labelMaxWidth) {
                        DlsText(L10n.string(action.titleKey), token: themeManager.current.fontTokens.bodyM_Book)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
        )
        .frame(minWidth: ChatMenu.minWidth)
        .fixedSize()
    }

    /// `DlsMenu` sizes itself from its labels' full width, so the cap has to be on the labels: `maxWidth` minus
    /// the menu chrome (tick slot and leading spacing, item and container padding) and the item's icon and gap.
    private var labelMaxWidth: CGFloat {
        let menu = themeManager.current.menu.size
        let icons = themeManager.current.iconTokens
        let menuIcon = switch menu.icon {
            case .small: icons.small
            case .medium: icons.regular
            case .large: icons.large
        }
        let chrome = 2 * menuIcon + 2 * menu.itemPaddingHorizontal + 4 * menu.paddingHorizontal
        let itemLeading = icons.regular + themeManager.current.dimensionTokens.size05
        return max(maxWidth - chrome - itemLeading, 0)
    }
}
