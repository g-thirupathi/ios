struct ChatTail: Equatable {
    let itemCount: Int
    let lastMessage: ChatMessage?
    let isAgentTyping: Bool
    let showsEndedCard: Bool
    let quickReplyKey: String?
}
