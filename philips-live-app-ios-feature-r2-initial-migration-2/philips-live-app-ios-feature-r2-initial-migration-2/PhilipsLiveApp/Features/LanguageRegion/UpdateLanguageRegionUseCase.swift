protocol UpdateLanguageRegionUseCase {
    func execute(country: SupportCountry, language: AppLanguage)
}

/// Saves the chosen support country and language and completes onboarding.
struct DefaultUpdateLanguageRegionUseCase: UpdateLanguageRegionUseCase {
    private let countryRepository: SupportCountryRepository
    private let languageRepository: LanguageRepository

    init(countryRepository: SupportCountryRepository, languageRepository: LanguageRepository) {
        self.countryRepository = countryRepository
        self.languageRepository = languageRepository
    }

    func execute(country: SupportCountry, language: AppLanguage) {
        countryRepository.completeOnboarding()
        countryRepository.select(country)
        languageRepository.select(language)
    }
}
