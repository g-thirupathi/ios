import SwiftUI

struct ChatScrollMetricsKey: PreferenceKey {
    nonisolated static let defaultValue = ChatScrollMetrics()

    nonisolated static func reduce(value: inout ChatScrollMetrics, nextValue: () -> ChatScrollMetrics) {
        let next = nextValue()
        if let anchorTop = next.anchorTop {
            value.anchorTop = anchorTop
        }
        if let oldestTop = next.oldestTop {
            value.oldestTop = oldestTop
        }
        if let endTop = next.endTop {
            value.endTop = endTop
        }
        if let height = next.viewportHeight {
            value.viewportHeight = height
        }
    }
}
