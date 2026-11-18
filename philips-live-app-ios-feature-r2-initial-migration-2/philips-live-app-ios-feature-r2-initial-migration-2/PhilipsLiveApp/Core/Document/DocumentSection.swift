import Foundation

struct DocumentSection: Identifiable {
    let id: Int
    let title: String?
    let paragraphs: [DocumentParagraph]
}
