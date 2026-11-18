import Foundation

final class RootViewModel: ObservableObject {
    @Published private(set) var language: AppLanguage

    private let languageRepository: LanguageRepository
    private let checkOnboarding: CheckOnboardingUseCase

    init(languageRepository: LanguageRepository, checkOnboarding: CheckOnboardingUseCase) {
        self.languageRepository = languageRepository
        self.checkOnboarding = checkOnboarding
        language = languageRepository.language
    }

    var locale: Locale {
        language.locale
    }

    var hasCompletedOnboarding: Bool {
        checkOnboarding.execute()
    }

    func observe() async {
        for await language in languageRepository.languages() where language != self.language {
            self.language = language
        }
    }
}
