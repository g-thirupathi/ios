/// Agent quick replies the user has not answered yet; `key` tells one set from another, so a dismissal sticks.
struct OpenQuickReply: Equatable {
    let key: String
    let options: [QuickReplyOption]
}
