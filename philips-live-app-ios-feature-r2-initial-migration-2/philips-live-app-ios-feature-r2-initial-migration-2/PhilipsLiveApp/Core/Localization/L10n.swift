import SwiftUI

/// The one way the app turns a string key into text. Nothing else calls `NSLocalizedString`, `Text("key")` or
/// `LocalizedStringKey("key")`, so how text is looked up (language, English fallback, logging) changes here only.
enum L10n {
    /// The text of `key` in the selected language or the one it falls back to, else in English, else the key itself.
    nonisolated static func string(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    /// For Filament APIs that only take a `LocalizedStringKey`: the finished text is passed as the key. It has no
    /// translation of its own, so it is shown as it is.
    static func key(_ key: String) -> LocalizedStringKey {
        LocalizedStringKey(string(key))
    }
}
