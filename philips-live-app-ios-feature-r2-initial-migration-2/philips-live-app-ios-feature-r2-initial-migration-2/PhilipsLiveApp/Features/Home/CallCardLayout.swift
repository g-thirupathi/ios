import SwiftUI

/// Lays out the call card's image, message and button. The image keeps its design width until the button's label
/// has shrunk to its minimum scale; only then does the image give up width.
struct CallCardLayout: Layout {
    let maxImageWidth: CGFloat
    let leadingGap: CGFloat
    let trailingInset: CGFloat
    let verticalInset: CGFloat
    let rowSpacing: CGFloat
    /// The part of the button that does not scale with its label: padding, icon and the gap between them.
    let buttonFixedWidth: CGFloat
    let buttonMinLabelScale: CGFloat
    let isRightToLeft: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews _: Subviews, cache _: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        guard subviews.count == 3 else { return }
        let (image, message, button) = (subviews[0], subviews[1], subviews[2])

        let naturalButtonWidth = button.sizeThatFits(.unspecified).width
        let minButtonWidth = buttonFixedWidth + (naturalButtonWidth - buttonFixedWidth) * buttonMinLabelScale
        let imageWidth = max(0, min(maxImageWidth, bounds.width - leadingGap - trailingInset - minButtonWidth))
        let columnX = imageWidth + leadingGap
        let columnWidth = max(0, bounds.width - columnX - trailingInset)

        let buttonSize = button.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
        let buttonWidth = min(buttonSize.width, columnWidth)
        let buttonY = bounds.height - verticalInset - buttonSize.height
        let messageHeight = max(0, buttonY - rowSpacing - verticalInset)

        place(image, offsetX: 0, offsetY: 0, size: CGSize(width: imageWidth, height: bounds.height), in: bounds)
        place(
            message,
            offsetX: columnX,
            offsetY: verticalInset,
            size: CGSize(width: columnWidth, height: messageHeight),
            in: bounds
        )
        place(
            button,
            offsetX: columnX,
            offsetY: buttonY,
            size: CGSize(width: buttonWidth, height: buttonSize.height),
            in: bounds
        )
    }

    private func place(_ subview: LayoutSubview, offsetX: CGFloat, offsetY: CGFloat, size: CGSize, in bounds: CGRect) {
        let originX = isRightToLeft ? bounds.maxX - offsetX - size.width : bounds.minX + offsetX
        subview.place(
            at: CGPoint(x: originX, y: bounds.minY + offsetY),
            anchor: .topLeading,
            proposal: ProposedViewSize(size)
        )
    }
}
