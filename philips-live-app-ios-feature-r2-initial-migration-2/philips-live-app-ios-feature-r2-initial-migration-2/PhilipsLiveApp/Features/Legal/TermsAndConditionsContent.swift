import SwiftUI

/// Builds the bundled terms: each section reads "Title: body" and the last section's last paragraph is bold.
enum TermsAndConditionsContent {
    static let sectionCount = 6

    static func make(bold: Font) -> DocumentContent {
        let intro = DocumentSection(
            id: 0,
            title: nil,
            paragraphs: [DocumentParagraph(id: 0, text: AttributedString(string("intro")))]
        )
        return DocumentContent(
            title: "TermsAndConditionsScreen.title",
            heading: "TermsAndConditionsScreen.heading",
            sections: [intro] + (0 ..< sectionCount).map { section(at: $0, bold: bold) }
        )
    }

    private static func section(at index: Int, bold: Font) -> DocumentSection {
        let title = string("sections.\(index).title")
        let paragraphs = string("sections.\(index).body").components(separatedBy: "\n\n")
        let isLastSection = index == sectionCount - 1
        return DocumentSection(
            id: index + 1,
            title: nil,
            paragraphs: paragraphs.enumerated().map { offset, paragraph in
                var text = AttributedString(paragraph)
                if isLastSection, offset == paragraphs.count - 1 {
                    text.font = bold
                }
                if offset == 0 {
                    var lead = AttributedString("\(title): ")
                    lead.font = bold
                    text = lead + text
                }
                return DocumentParagraph(id: offset, text: text)
            }
        )
    }

    private static func string(_ key: String) -> String {
        L10n.string("TermsAndConditionsScreen.\(key)")
    }
}
