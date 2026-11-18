import CoreGraphics

enum ChatScroll {
    static let space = "chatScroll"
    /// What scrolling to the bottom targets, and the oldest row, which scrolling to the top targets.
    static let bottomAnchorId = "chat.bottom"
    static let oldestAnchorId = "chat.oldest"
    /// Near the end of the list the scroll-to-latest button is hidden; away from it, it shows. The list moves away
    /// beyond `awayDistance` and comes back within `nearDistance`, so the measured distance, which wobbles as rows
    /// below are re-estimated, doesn't flip it. Messages from others are followed within `nearDistance`.
    static let awayDistance: CGFloat = 200
    static let nearDistance: CGFloat = 100
}
