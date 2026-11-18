import UIKit

/// Decoded thumbnails, so a row that is laid out again (lazy list, keyboard resize) shows its image in the first
/// frame instead of going through a placeholder like `AsyncImage` does, which has no cache for local files.
final class AttachmentThumbnailCache {
    static let shared = AttachmentThumbnailCache()

    /// `pixelSize` is the longest side the image was decoded for, which a view compares with what it needs.
    final class Entry {
        let image: UIImage
        let pixelSize: CGFloat

        init(image: UIImage, pixelSize: CGFloat) {
            self.image = image
            self.pixelSize = pixelSize
        }
    }

    private let cache = NSCache<NSURL, Entry>()

    func entry(for url: URL) -> Entry? {
        cache.object(forKey: url as NSURL)
    }

    /// Keeps the larger decode of a file: it serves smaller views too, while a smaller one would blur bigger views.
    func store(_ image: UIImage, pixelSize: CGFloat, for url: URL) {
        guard pixelSize > (entry(for: url)?.pixelSize ?? 0) else { return }
        cache.setObject(Entry(image: image, pixelSize: pixelSize), forKey: url as NSURL)
    }
}
