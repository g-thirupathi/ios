import SwiftUI

/// Builds the bundled notice: paragraphs split on blank lines, the first sentence of a bullet in bold, and
/// at most the first two mentions of the Philips privacy notice in the whole text linking to the web version.
enum PrivacyPolicyContent {
    static let sectionCount = 9
    static let maxLinks = 2

    private static let noticeURL = URL(string: "https://www.philips.com/a-w/privacy-notice.html")
    private static let linkTail = "de Philips"
    private static let noticePattern = try? NSRegularExpression(
        pattern: "(Philips Privacy Notice|Philips privacy notice|Aviso de Privacidad global de Philips"
            + "|aviso global de privacidad de Philips|Declaração de Privacidade global da Philips"
            + "|declaração de Privacidade global da Philips)"
    )
    private static let bulletPattern = try? NSRegularExpression(pattern: "^(•\\s*)([^.]+\\.)(\\s*)(.*)$")

    static func make(bold: Font) -> DocumentContent {
        DocumentContent(
            title: "PrivacyPolicyScreen.title",
            heading: "PrivacyPolicyScreen.heading",
            subheading: "PrivacyPolicyScreen.last_updated",
            sections: sections(bold: bold)
        )
    }

    private static func sections(bold: Font) -> [DocumentSection] {
        var links = 0
        return (0 ..< sectionCount).map { index in
            let title = L10n.string("PrivacyPolicyScreen.sections.\(index).title")
            let body = L10n.string("PrivacyPolicyScreen.sections.\(index).body")
            let paragraphs = body.components(separatedBy: "\n\n").enumerated().map { offset, paragraph in
                DocumentParagraph(id: offset, text: attributed(paragraph, links: &links, bold: bold))
            }
            return DocumentSection(id: index, title: title, paragraphs: paragraphs)
        }
    }

    private static func attributed(_ paragraph: String, links: inout Int, bold: Font) -> AttributedString {
        let range = NSRange(paragraph.startIndex..., in: paragraph)
        guard let match = bulletPattern?.firstMatch(in: paragraph, range: range),
              let bullet = Range(match.range(at: 1), in: paragraph),
              let lead = Range(match.range(at: 2), in: paragraph),
              let gap = Range(match.range(at: 3), in: paragraph),
              let rest = Range(match.range(at: 4), in: paragraph)
        else {
            return linked(paragraph, links: &links)
        }
        var leadText = AttributedString(paragraph[lead])
        leadText.font = bold
        return AttributedString(paragraph[bullet]) + leadText + AttributedString(paragraph[gap])
            + linked(String(paragraph[rest]), links: &links)
    }

    private static func linked(_ text: String, links: inout Int) -> AttributedString {
        var result = AttributedString()
        var cursor = text.startIndex
        let matches = noticePattern?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            result += AttributedString(text[cursor ..< range.lowerBound])
            var linkStart = range.lowerBound
            if links < maxLinks, let tail = text[range].range(of: linkTail) {
                result += AttributedString(text[range.lowerBound ..< tail.lowerBound])
                linkStart = tail.lowerBound
            }
            var mention = AttributedString(text[linkStart ..< range.upperBound])
            if links < maxLinks {
                mention.link = noticeURL
                mention.underlineStyle = .single
                links += 1
            }
            result += mention
            cursor = range.upperBound
        }
        return result + AttributedString(text[cursor...])
    }
}
