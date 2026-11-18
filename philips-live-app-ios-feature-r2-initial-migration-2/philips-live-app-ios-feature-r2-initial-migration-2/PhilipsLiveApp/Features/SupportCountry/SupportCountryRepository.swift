import OSLog

protocol SupportCountryRepository {
    /// The chosen country, or the default when none was chosen.
    func selectedCountry() -> SupportCountry
    /// The chosen country, or nil when none was chosen.
    func storedCountry() -> SupportCountry?
    func select(_ country: SupportCountry)
    func isOnboardingCompleted() -> Bool
    func completeOnboarding()
}

struct DefaultSupportCountryRepository: SupportCountryRepository {
    static let selectedCountryKey = "philipslive:selectedSupportCountryCode"
    static let onboardingCompletedKey = "philipslive:onboardingCompleted"

    private let preferences: PreferencesLocalDataSource
    private let logger = Logger(category: "SupportCountryRepository")

    init(preferences: PreferencesLocalDataSource) {
        self.preferences = preferences
    }

    func selectedCountry() -> SupportCountry {
        storedCountry() ?? .default
    }

    func storedCountry() -> SupportCountry? {
        do {
            return try preferences.string(forKey: Self.selectedCountryKey).flatMap(SupportCountry.init)
        } catch {
            logger.error("Load selected support country failed: \(error)")
            return nil
        }
    }

    func select(_ country: SupportCountry) {
        do {
            try preferences.set(country.rawValue, forKey: Self.selectedCountryKey)
        } catch {
            logger.error("Save selected support country failed: \(error)")
        }
    }

    func isOnboardingCompleted() -> Bool {
        do {
            return try preferences.string(forKey: Self.onboardingCompletedKey) == "true"
        } catch {
            logger.error("Load onboarding completion failed: \(error)")
            return false
        }
    }

    func completeOnboarding() {
        do {
            try preferences.set("true", forKey: Self.onboardingCompletedKey)
        } catch {
            logger.error("Save onboarding completion failed: \(error)")
        }
    }
}
