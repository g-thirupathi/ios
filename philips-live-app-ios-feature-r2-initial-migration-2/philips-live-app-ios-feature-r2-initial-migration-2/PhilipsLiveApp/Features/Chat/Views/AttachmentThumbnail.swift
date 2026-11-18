import Filament
import ImageIO
import SwiftUI

struct AttachmentThumbnail: View {
    @EnvironmentObject private var themeManager: DlsThemeManager
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var pixelSize: CGFloat

    let url: URL

    init(url: URL) {
        self.url = url
        let cached = AttachmentThumbnailCache.shared.entry(for: url)
        _image = State(initialValue: cached?.image)
        _pixelSize = State(initialValue: cached?.pixelSize ?? 0)
    }

    private struct Request: Equatable {
        let url: URL
        let size: CGSize
    }

    /// Decodes the image large enough to fill the size it is shown at, once that size is known.
    var body: some View {
        GeometryReader { proxy in
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    themeManager.current.colorTokens.container.background.secondary
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .task(id: proxy.size == .zero ? nil : Request(url: url, size: proxy.size)) {
                await load(filling: proxy.size)
            }
        }
        // `clipped()` leaves the part of a filled image outside the frame tappable, where it would cover the views
        // next to it.
        .allowsHitTesting(false)
    }

    /// Decodes again only when what is shown is smaller than needed, e.g. a chip's image reused in a bigger bubble.
    private func load(filling box: CGSize) async {
        guard box.width > 0, box.height > 0 else { return }
        let (url, scale, decoded) = (url, displayScale, pixelSize)
        let loaded = await Task.detached(priority: .userInitiated) {
            Self.downsampledImage(at: url, filling: box, scale: scale, decoded: decoded)
        }.value
        guard let loaded else { return }
        AttachmentThumbnailCache.shared.store(loaded.image, pixelSize: loaded.pixelSize, for: url)
        image = loaded.image
        pixelSize = loaded.pixelSize
    }

    private nonisolated static func downsampledImage(
        at url: URL,
        filling box: CGSize,
        scale: CGFloat,
        decoded: CGFloat
    ) -> (image: UIImage, pixelSize: CGFloat)? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let pixelSize = fillingPixelSize(of: source, box: box, scale: scale)
        guard pixelSize > decoded else { return nil }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelSize,
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions)
            .map { (UIImage(cgImage: $0), pixelSize) }
    }

    /// EXIF orientations 5 to 8 turn the image a quarter turn, so its width and height swap.
    private nonisolated static let uprightOrientation = 1
    private nonisolated static let firstSidewaysOrientation = 5

    /// The longest side, in pixels, for the image to cover `box` when scaled to fill, never beyond its own size.
    /// The thumbnail is turned upright, so a sideways photo is measured the other way round.
    private nonisolated static func fillingPixelSize(of source: CGImageSource, box: CGSize, scale: CGFloat) -> CGFloat {
        let boxWidth = box.width * scale
        let boxHeight = box.height * scale
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width > 0, height > 0
        else { return max(boxWidth, boxHeight).rounded(.up) }
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? Self.uprightOrientation
        let (imageWidth, imageHeight) = orientation >= Self.firstSidewaysOrientation ? (height, width) : (width, height)
        let fill = max(boxWidth / imageWidth, boxHeight / imageHeight)
        let longest = max(imageWidth, imageHeight)
        return min(longest * fill, longest).rounded(.up)
    }
}
