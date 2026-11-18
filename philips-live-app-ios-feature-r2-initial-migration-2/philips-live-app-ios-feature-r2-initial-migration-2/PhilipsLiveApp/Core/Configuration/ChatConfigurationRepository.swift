protocol ChatConfigurationRepository {
    /// The Genesys deployment built in for the country, or nil when there is none.
    func configuration(for country: SupportCountry) -> ChatConfiguration?
}

struct DefaultChatConfigurationRepository: ChatConfigurationRepository {
    private let provider: AppConfigurationProvider

    init(provider: AppConfigurationProvider) {
        self.provider = provider
    }

    func configuration(for country: SupportCountry) -> ChatConfiguration? {
        provider.chatConfiguration(for: country)
    }
}
