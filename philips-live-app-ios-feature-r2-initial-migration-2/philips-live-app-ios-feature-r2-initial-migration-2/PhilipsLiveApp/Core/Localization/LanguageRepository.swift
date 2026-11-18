import Foundation
import OSLog

protocol LanguageRepository: AnyObject {
    var language: AppLanguage { get }
    func languages() -> AsyncStream<AppLanguage>
    func select(_ language: AppLanguage)
}

/// The app language chosen in Language & Region: persisted, applied to string lookups and published.
final class DefaultLanguageRepository: LanguageRepository {
    static let selectedLanguageKey = "philipslive:selectedLanguageCode"

    private(set) var language: AppLanguage

    private let preferences: PreferencesLocalDataSource
    private let localization: LocalizationProvider
    private var continuations: [UUID: AsyncStream<AppLanguage>.Continuation] = [:]
    private let logger = Logger(category: "LanguageRepository")

    init(preferences: PreferencesLocalDataSource, localization: LocalizationProvider) {
        self.preferences = preferences
        self.localization = localization
        var stored: AppLanguage?
        do {
            stored = try preferences.string(forKey: Self.selectedLanguageKey).flatMap(AppLanguage.init)
        } catch {
            logger.error("Load selected language failed: \(error)")
        }
        language = stored ?? .default
        localization.apply(language)
    }

    func languages() -> AsyncStream<AppLanguage> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.yield(language)
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.continuations[id] = nil }
            }
        }
    }

    func select(_ newLanguage: AppLanguage) {
        guard newLanguage != language else { return }
        do {
            try preferences.set(newLanguage.rawValue, forKey: Self.selectedLanguageKey)
        } catch {
            logger.error("Save selected language failed: \(error)")
        }
        localization.apply(newLanguage)
        language = newLanguage
        continuations.values.forEach { $0.yield(newLanguage) }
    }
}
