protocol GetChatConfigurationUseCase {
    func execute() -> ChatConfiguration?
}

/// The Genesys deployment of the selected support country.
struct DefaultGetChatConfigurationUseCase: GetChatConfigurationUseCase {
    private let countryRepository: SupportCountryRepository
    private let configurationRepository: ChatConfigurationRepository

    init(countryRepository: SupportCountryRepository, configurationRepository: ChatConfigurationRepository) {
        self.countryRepository = countryRepository
        self.configurationRepository = configurationRepository
    }

    func execute() -> ChatConfiguration? {
        configurationRepository.configuration(for: countryRepository.selectedCountry())
    }
}
