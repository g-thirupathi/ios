import SwiftUI

struct ChatMenuAnchorsKey: PreferenceKey {
    nonisolated static let defaultValue = ChatMenuAnchors()

    nonisolated static func reduce(value: inout ChatMenuAnchors, nextValue: () -> ChatMenuAnchors) {
        let next = nextValue()
        value.header = next.header ?? value.header
        value.aboveInput = next.aboveInput ?? value.aboveInput
    }
}
