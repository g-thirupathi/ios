import SwiftUI

extension View {
    /// Marks what scrolling to the bottom targets.
    func chatScrollAnchor() -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ChatScrollMetricsKey.self,
                    value: ChatScrollMetrics(anchorTop: geometry.frame(in: .named(ChatScroll.space)).minY)
                )
            }
        }
    }

    /// Marks what scrolling to the oldest message targets.
    func chatScrollOldestAnchor() -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ChatScrollMetricsKey.self,
                    value: ChatScrollMetrics(oldestTop: geometry.frame(in: .named(ChatScroll.space)).minY)
                )
            }
        }
    }

    /// Marks the oldest end of the content.
    func chatScrollEnd() -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ChatScrollMetricsKey.self,
                    value: ChatScrollMetrics(endTop: geometry.frame(in: .named(ChatScroll.space)).minY)
                )
            }
        }
    }

    /// Turns the list upside down, so it runs from the input up and keeps its bottom when it changes height, and
    /// each row in it back.
    func chatScrollFlipped() -> some View {
        scaleEffect(x: 1, y: -1)
    }

    func chatScrollViewport() -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ChatScrollMetricsKey.self,
                    value: ChatScrollMetrics(viewportHeight: geometry.size.height)
                )
            }
        }
    }
}
