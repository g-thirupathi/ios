import OSLog
import SwiftUI

/// Builds the third-party notices from the bundled `Licenses.json`: a bullet with the library name,
/// version and license, followed by the full notice.
enum LicensesContent {
    private struct LicenseGroup: Decodable {
        let items: [LicenseItem]
    }

    private struct LicenseItem: Decodable {
        let name: String?
        let version: String?
        let license: String?
        let packages: [String]?
        let notice: String?
    }

    private static let logger = Logger(category: "LicensesContent")
    /// R1 has no strings for these three: its licenses screen shows them in English only.
    private static let intro =
        "THIRD PARTIES. Philips Service Live mobile app uses the following third party libraries:"
    private static let versionLabel = "Version"
    private static let licenseLabel = "License"

    static func make(fonts: DocumentFonts) -> DocumentContent {
        let intro = DocumentSection(
            id: 0,
            title: nil,
            paragraphs: [DocumentParagraph(id: 0, text: AttributedString(Self.intro))]
        )
        let items = loadGroups().flatMap(\.items).enumerated().map { index, item in
            var paragraphs = [DocumentParagraph(id: 0, text: header(of: item, bold: fonts.bold))]
            if let notice = item.notice {
                var text = AttributedString(notice)
                text.font = fonts.small
                paragraphs.append(DocumentParagraph(id: 1, text: text))
            }
            return DocumentSection(id: index + 1, title: nil, paragraphs: paragraphs)
        }
        return DocumentContent(title: "AboutScreen.links.0.label", sections: [intro] + items)
    }

    private static let bullet = "\u{2022} "

    private static func header(of item: LicenseItem, bold: Font) -> AttributedString {
        var text = AttributedString()
        for (index, name) in (item.packages ?? item.name.map { [$0] } ?? []).enumerated() {
            var entry = AttributedString(name)
            entry.font = bold
            text += AttributedString((index == 0 ? "" : "\n") + bullet) + entry
        }
        guard item.packages == nil else { return text }
        for (label, value) in [(versionLabel, item.version), (licenseLabel, item.license)] {
            if let value {
                text += AttributedString("\n\(label): \(value)")
            }
        }
        return text
    }

    private static func loadGroups() -> [LicenseGroup] {
        guard let url = Bundle.main.url(forResource: "Licenses", withExtension: "json") else {
            logger.error("Licenses.json is missing from the bundle")
            return []
        }
        do {
            return try JSONDecoder().decode([LicenseGroup].self, from: Data(contentsOf: url))
        } catch {
            logger.error("Load licenses failed: \(error)")
            return []
        }
    }
}
