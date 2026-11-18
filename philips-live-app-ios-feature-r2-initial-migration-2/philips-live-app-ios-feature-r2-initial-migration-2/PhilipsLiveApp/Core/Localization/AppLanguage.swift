import Foundation

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case spanish = "es"
    case portuguese = "pt"
    case spanishPuertoRico = "es-PR"

    static let `default`: AppLanguage = .english

    /// Puerto Rico Spanish shows Spain Spanish for texts it has no translation of, before English.
    var lookupOrder: [AppLanguage] {
        switch self {
            case .spanishPuertoRico: [self, .spanish]
            default: [self]
        }
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    /// Fixed labels, so the picker reads the same in every language.
    var displayName: String {
        switch self {
            case .english: "English"
            case .spanish: "Español"
            case .portuguese: "Portuguese"
            case .spanishPuertoRico: "Español (Puerto Rico)"
        }
    }
}
