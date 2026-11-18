import Filament
import SwiftUI

struct LanguageRegionScreen: View {
    @EnvironmentObject private var themeManager: DlsThemeManager
    @StateObject private var viewModel: LanguageRegionViewModel

    let onContinue: () -> Void

    init(
        viewModel: @autoclosure @escaping () -> LanguageRegionViewModel,
        onContinue: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onContinue = onContinue
    }

    var body: some View {
        let theme = themeManager.current
        let primary = theme.colorTokens.foreground.color.primary
        TopBarContainer(
            titleKey: "LanguageRegionScreen.title",
            backLabelKey: "LanguageRegionScreen.back"
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.dimensionTokens.size17) {
                    VStack(alignment: .leading, spacing: theme.dimensionTokens.size09) {
                        DlsText(
                            L10n.string("LanguageRegionScreen.heading"),
                            token: theme.fontTokens.bodyM_Bold,
                            foregroundStyle: primary
                        )
                        DlsText(
                            L10n.string("LanguageRegionScreen.description"),
                            token: theme.fontTokens.bodyS_Book,
                            foregroundStyle: primary
                        )
                    }
                    countryDropdown
                    languageField
                    DlsButton(L10n.string("LanguageRegionScreen.continue"), fullWidth: true) {
                        onContinue()
                        viewModel.saveAndFinishOnboarding()
                    }
                    .disabled(!viewModel.canContinue)
                }
                .padding(.horizontal, theme.dimensionTokens.size11)
                .padding(.vertical, theme.dimensionTokens.size11)
            }
            .bouncesOnlyWhenScrollable()
        }
    }

    private var countryDropdown: some View {
        DlsDropDown(
            L10n.key("LanguageRegionScreen.country_placeholder"),
            items: viewModel.countries.map(\.displayName),
            selection: Binding<String?>(
                get: { viewModel.country?.displayName },
                set: { name in
                    if let country = viewModel.countries.first(where: { $0.displayName == name }) {
                        viewModel.select(country)
                    }
                }
            )
        ) { name in
            Text(name)
        }
    }

    /// The language follows the country, so this only shows it.
    private var languageField: some View {
        DlsTextField(
            text: Binding(get: { viewModel.language?.displayName ?? "" }, set: { _ in }),
            prompt: L10n.key("LanguageRegionScreen.language_placeholder"),
            showClearButton: false
        )
        .disabled(true)
    }
}
