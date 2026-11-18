import Foundation
import ImageIO
import UniformTypeIdentifiers

protocol ImageConversionProvider {
    /// Returns the image as it is when its type is one of `mimeTypes`, otherwise re-encoded as JPEG.
    func compatibleImage(_ data: Data, keeping mimeTypes: Set<String>) async -> CompatibleImage
}

struct ImageIOImageConversionProvider: ImageConversionProvider {
    private static let defaultFileExtension = "jpg"

    func compatibleImage(_ data: Data, keeping mimeTypes: Set<String>) async -> CompatibleImage {
        let (data, type) = await Self.convert(data, keeping: mimeTypes.compactMap { UTType(mimeType: $0) })
        return CompatibleImage(
            data: data,
            fileExtension: type.preferredFilenameExtension ?? Self.defaultFileExtension,
            mimeType: type.preferredMIMEType
        )
    }

    @concurrent
    private static func convert(_ data: Data, keeping supported: [UTType]) async -> (Data, UTType) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let identifier = CGImageSourceGetType(source) as String?,
              let type = UTType(identifier)
        else { return (data, .jpeg) }
        if supported.contains(where: type.conforms(to:)) {
            return (data, type)
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
        else { return (data, type) }
        let options = [kCGImageDestinationLossyCompressionQuality: ImageCompression.jpegQuality] as CFDictionary
        CGImageDestinationAddImageFromSource(destination, source, 0, options)
        guard CGImageDestinationFinalize(destination) else { return (data, type) }
        return (output as Data, .jpeg)
    }
}
