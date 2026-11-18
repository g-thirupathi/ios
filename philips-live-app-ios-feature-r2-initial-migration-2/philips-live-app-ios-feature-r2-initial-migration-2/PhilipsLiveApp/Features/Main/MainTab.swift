import Filament
import SwiftUI

enum MainTab: Tabbable {
    case home
    case settings

    var id: UUID {
        switch self {
            case .home: Self.homeID
            case .settings: Self.settingsID
        }
    }

    var iconAsset: DlsAsset? {
        switch self {
            case .home: .home
            case .settings: .settings
        }
    }

    var title: String? {
        switch self {
            case .home: L10n.string("HomeScreen.tab_label")
            case .settings: L10n.string("SettingsScreen.tab_label")
        }
    }

    var orientation: DlsLayoutDirection {
        .vertical
    }

    var badgeCount: Int {
        0
    }

    var badgeVariant: DlsBadgeStateVariant {
        .normal
    }

    var badgeType: DlsBadgeVariant {
        .normal
    }

    var useCustomView: Bool {
        false
    }

    var customView: () -> AnyView {
        { AnyView(EmptyView()) }
    }

    /// The tab bar tracks tabs by a stable `UUID`, so these are fixed rather than generated per access.
    private static let homeID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x01))
    private static let settingsID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x02))
}
