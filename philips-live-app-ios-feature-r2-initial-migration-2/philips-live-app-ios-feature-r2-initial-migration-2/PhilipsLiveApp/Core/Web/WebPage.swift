import Foundation

struct WebPage: Identifiable {
    let url: URL

    var id: URL {
        url
    }

    /// `SFSafariViewController` raises an exception for anything but http(s).
    init?(url: URL) {
        guard url.scheme == "https" || url.scheme == "http" else { return nil }
        self.url = url
    }

    init?(localizedURLKey key: String) {
        guard let url = URL(string: L10n.string(key)) else { return nil }
        self.init(url: url)
    }
}
