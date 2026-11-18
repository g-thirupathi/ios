extension SupportCountry {
    /// Shares one chat deployment with other countries, which tells its flow the user's country.
    var sharesMetaChat: Bool {
        switch self {
            case .unitedArabEmirates, .oman, .qatar: true
            default: false
        }
    }

    /// Without a domain of its own the chat uses the default one.
    var usesDefaultChatDomain: Bool {
        self == .spain || self == .portugal
    }

    /// The chat's options menu, for now only "End chat", exists only for India.
    var hasChatOptionsMenu: Bool {
        self == .india
    }
}
