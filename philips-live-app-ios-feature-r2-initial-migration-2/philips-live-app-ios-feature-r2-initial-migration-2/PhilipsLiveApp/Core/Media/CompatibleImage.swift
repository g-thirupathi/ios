import Foundation

nonisolated struct CompatibleImage: Sendable {
    let data: Data
    let fileExtension: String
    let mimeType: String?
}
