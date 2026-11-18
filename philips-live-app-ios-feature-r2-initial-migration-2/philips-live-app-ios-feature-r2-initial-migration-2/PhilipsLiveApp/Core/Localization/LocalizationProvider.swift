import Foundation
import ObjectiveC.runtime

protocol LocalizationProvider {
    func apply(_ language: AppLanguage)
}

/// Switches the app language at runtime by routing `Bundle.main` string lookups to the selected `.lproj`.
/// Only lookups through `Bundle.main.localizedString` follow the switch, which is why all text goes through `L10n`.
struct BundleLocalizationProvider: LocalizationProvider {
    func apply(_ language: AppLanguage) {
        LocalizedBundle.route(to: language.lookupOrder.map(\.rawValue))
    }
}
