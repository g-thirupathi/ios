import Filament
import SwiftUI

/// Settings tab.
struct SettingsScreen: View {
    private struct Row: Identifiable {
        let icon: DlsAsset
        let titleKey: String
        var destination: SettingsDestination?

        var id: String {
            titleKey
        }
    }

    @EnvironmentObject private var themeManager: DlsThemeManager

    private var rows: [Row] {
        [
            Row(icon: .informationCircleFill, titleKey: "SettingsScreen.about", destination: .about),
            Row(icon: .documentTextView, titleKey: "SettingsScreen.privacy", destination: .privacyPolicy),
            Row(icon: .warning, titleKey: "SettingsScreen.disclaimer", destination: .disclaimer),
        ]
    }

    private var dimensions: DlsDimensionTokens {
        themeManager.current.dimensionTokens
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DlsText(L10n.string("SettingsScreen.title"), token: themeManager.current.fontTokens.headingM_Bold)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, dimensions.size11)
                .padding(.bottom, dimensions.size05)
            ScrollView {
                VStack(spacing: dimensions.size02) {
                    ForEach(rows) { row in
                        rowView(row)
                    }
                }
                .padding(.horizontal, dimensions.size05)
                .padding(.top, dimensions.size07)
            }
            .bouncesOnlyWhenScrollable()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background { themeManager.current.colorTokens.container.background.primary.ignoresSafeArea() }
        .navigationDestination(for: SettingsDestination.self) { destination in
            switch destination {
                case .about: AboutScreen()
                case .privacyPolicy: LegalDocumentScreen(.privacyPolicy)
                case .disclaimer: DisclaimerScreen()
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: Row) -> some View {
        let item = DlsListItem(
            contentLeft: { DlsIcon(row.icon) },
            headline: L10n.key(row.titleKey),
            contentRight: { DlsIcon(.chevronRight) }
        )
        if let destination = row.destination {
            NavigationLink(value: destination) {
                item
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            item
        }
    }
}
