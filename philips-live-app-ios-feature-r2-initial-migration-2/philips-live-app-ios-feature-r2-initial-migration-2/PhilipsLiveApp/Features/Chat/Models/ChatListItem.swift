import Foundation

enum ChatListItem: Equatable {
    case message(ChatMessage)
    case closedDivider(Date)
}
