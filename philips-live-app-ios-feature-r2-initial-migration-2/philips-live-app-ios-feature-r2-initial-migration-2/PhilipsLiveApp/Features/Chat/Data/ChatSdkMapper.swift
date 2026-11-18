import Foundation
@preconcurrency import MessengerTransport

enum ChatSdkMapper {
    static func attachment(_ attachment: Attachment) -> ChatAttachment {
        ChatAttachment(
            id: attachment.id,
            fileName: attachment.fileName ?? "",
            fileSize: attachment.fileSizeInBytes?.intValue,
            downloadUrl: downloadUrl(attachment.state)
        )
    }

    static func deliveryState(_ state: Message.State) -> DeliveryState {
        switch state {
            case is Message.StateSent: .sent
            case is Message.StateSending: .sending
            case is Message.StateError: .failed
            default: .idle
        }
    }

    static func uploadState(_ state: Attachment.State) -> AttachmentUploadState {
        switch state {
            case is Attachment.StatePresigning: .presigning
            case is Attachment.StateUploading: .uploading
            case is Attachment.StateUploaded: .uploaded
            case is Attachment.StateSending: .sending
            case is Attachment.StateSent: .sent
            case is Attachment.StateDetaching: .detaching
            case is Attachment.StateDetached: .detached
            case is Attachment.StateError: .error
            default: .unknown
        }
    }

    static func downloadUrl(_ state: Attachment.State) -> String? {
        switch state {
            case let refreshed as Attachment.StateRefreshed: refreshed.downloadUrl
            case let sent as Attachment.StateSent: sent.downloadUrl
            case let uploaded as Attachment.StateUploaded: uploaded.downloadUrl
            default: nil
        }
    }

    static func date(_ epochMilliseconds: KotlinLong?) -> Date? {
        epochMilliseconds.flatMap { Date(epochValue: Double($0.int64Value)) }
    }

    static func message(_ message: Message) -> ChatMessage {
        let isFromUser = message.direction == .inbound
        return ChatMessage(
            id: message.id,
            direction: isFromUser ? .inbound : .outbound,
            text: message.text ?? "",
            state: deliveryState(message.state),
            timestamp: date(message.timeStamp),
            attachments: message.attachments.values.filter { !isFromUser || isOwnMessagePart($0.state) }
                .map(attachment),
            sender: isFromUser ? nil : sender(message.from)
        )
    }

    static func sender(_ participant: Message.Participant) -> ChatSender {
        let entity = participant.originatingEntity
        let kind: ChatSender.Kind = if entity == .bot {
            .bot
        } else if entity == .human {
            .human
        } else {
            .unknown
        }
        return ChatSender(kind: kind, name: participant.name, imageUrl: participant.imageUrl)
    }

    /// The SDK copies its whole pending message into the own message it inserts, and sends only the `Uploaded`
    /// entries. The others belong to earlier messages the chat has not confirmed yet (`Sending`), or never go out
    /// (refreshed to open them, detached or failed). An own message from the chat itself has `Sent` ones.
    private static func isOwnMessagePart(_ state: Attachment.State) -> Bool {
        state is Attachment.StateUploaded || state is Attachment.StateSent
    }

    /// Message events other than attachment updates, which the data source handles itself.
    static func event(_ messageEvent: MessageEvent) -> ChatEvent? {
        switch messageEvent {
            case let inserted as MessageEvent.MessageInserted:
                .messageInserted(message(inserted.message))
            case let updated as MessageEvent.MessageUpdated:
                .messageUpdated(
                    id: updated.message.id,
                    state: deliveryState(updated.message.state),
                    timestamp: date(updated.message.timeStamp)
                )
            case let quickReply as MessageEvent.QuickReplyReceived:
                .quickReplyReceived(
                    text: quickReply.message.text ?? "",
                    options: quickReply.message.quickReplies
                        .map { QuickReplyOption(text: $0.text, payload: $0.payload) },
                    sender: sender(quickReply.message.from)
                )
            default:
                nil
        }
    }

    static func event(_ event: Event) -> ChatEvent? {
        switch event {
            case let typing as Event.AgentTyping:
                .agentTyping(durationMilliseconds: typing.durationInMilliseconds)
            case is Event.ConversationDisconnect:
                .chatEnded
            case is Event.ConversationCleared:
                .conversationClearAnswered(isCleared: true)
            case let failure as Event.Error where failure.errorCode is ErrorCode.ClearConversationFailure:
                .conversationClearAnswered(isCleared: false)
            default:
                nil
        }
    }

    /// Genesys errors carry no code for a call in the wrong state, so it is recognised by the message of the SDK's
    /// state check: "MessagingClient is not Configured or in ReadOnly state." (checked in 2.16.0).
    static func error(_ error: Error) -> ChatError {
        matches(error, "not configured") ? .notConfigured : .sdk(error)
    }

    /// The SDK gave up reaching Genesys: no network, or its websocket could not reconnect.
    static func isNetworkFailure(_ state: MessagingClientState) -> Bool {
        guard let error = state as? MessagingClientState.Error else { return false }
        return error.code is ErrorCode.NetworkDisabled || error.code is ErrorCode.WebsocketError
    }

    /// What an SDK error state means for the user. Genesys refusing the app, or having no such deployment, does not go
    /// away by trying again; anything else might. A failure to reach the network counts too, as the chat gave up: the
    /// session ignores it while the phone itself is offline.
    static func failure(of state: MessagingClientState) -> ChatConnectionError? {
        guard let error = state as? MessagingClientState.Error else { return nil }
        let isRefused = error.code is ErrorCode.WebsocketAccessDenied || error.code is ErrorCode.DeploymentIdMismatch
            || error.code is ErrorCode.MissingDeploymentConfig
        return isRefused ? .unavailable : .connectionFailed
    }

    private static func matches(_ error: Error, _ pattern: String) -> Bool {
        let text = "\(error.localizedDescription) \(String(describing: error))"
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
