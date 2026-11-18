import Filament
import SwiftUI

/// The dropdown under the three-dots button. Sized like the attachment menu, which opens from the opposite corner.
struct ChatOptionsMenu: View {
    enum Action: CaseIterable, Hashable {
        case endChat
    }

    @EnvironmentObject private var themeManager: DlsThemeManager
    @State private var selection: Action?

    let isEndChatEnabled: Bool
    let onSelect: (Action) -> Void

    var body: some View {
        DlsMenu(
            items: Action.allCases,
            disabledItems: isEndChatEnabled ? [] : [.endChat],
            selection: $selection,
            onSelect: {
                guard let action = selection else { return }
                selection = nil
                onSelect(action)
            },
            content: { _ in
                DlsText(L10n.string("ChatScreen.end_chat"), token: themeManager.current.fontTokens.bodyM_Book)
                    .lineLimit(1)
            }
        )
        .frame(minWidth: ChatMenu.minWidth)
        .fixedSize()
    }
}
