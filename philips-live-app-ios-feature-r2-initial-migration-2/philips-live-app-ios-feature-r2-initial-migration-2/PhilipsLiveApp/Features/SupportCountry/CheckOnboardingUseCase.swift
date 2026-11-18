protocol CheckOnboardingUseCase {
    func execute() -> Bool
}

/// A stored country also counts as completed, so users updating from R1 skip the onboarding.
struct DefaultCheckOnboardingUseCase: CheckOnboardingUseCase {
    private let countryRepository: SupportCountryRepository

    init(countryRepository: SupportCountryRepository) {
        self.countryRepository = countryRepository
    }

    func execute() -> Bool {
        if countryRepository.isOnboardingCompleted() {
            return true
        }
        guard countryRepository.storedCountry() != nil else { return false }
        countryRepository.completeOnboarding()
        return true
    }
}
