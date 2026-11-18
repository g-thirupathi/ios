import Foundation

/// Who wrote an agent message, as the chat reports it. Messages saved by R1 have none.
struct ChatSender: Codable, Equatable {
    enum Kind: String, Codable {
        case bot
        case human
        case unknown
    }

    var kind: Kind
    var name: String?
    var imageUrl: String?
}
