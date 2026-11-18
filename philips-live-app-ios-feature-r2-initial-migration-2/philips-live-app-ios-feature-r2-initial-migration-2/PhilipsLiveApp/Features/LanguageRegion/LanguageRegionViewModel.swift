import Foundation

final class LanguageRegionViewModel: ObservableObject {
    @Published private(set) var country: SupportCountry?

    let countries = SupportCountry.allCases

    private let updateLanguageRegion: UpdateLanguageRegionUseCase

    init(updateLanguageRegion: UpdateLanguageRegionUseCase) {
        self.updateLanguageRegion = updateLanguageRegion
    }

    var language: AppLanguage? {
        country?.defaultLanguage
    }

    var canContinue: Bool {
        country != nil
    }

    func select(_ country: SupportCountry) {
        self.country = country
    }

    func saveAndFinishOnboarding() {
        guard let country else { return }
        updateLanguageRegion.execute(country: country, language: country.defaultLanguage)
    }
}
