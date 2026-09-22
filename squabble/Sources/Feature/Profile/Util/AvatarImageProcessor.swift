import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Turns whatever the photo picker hands over (HEIC, a 48-megapixel JPEG…) into a small
/// square JPEG that's cheap to upload and to download on every bill.
nonisolated enum AvatarImageProcessor {
    static let pixelSize = 512
    static let quality = 0.8

    static func squareJPEG(from data: Data, pixelSize: Int = pixelSize) -> Data? {
        guard let image = squareImage(from: data, pixelSize: pixelSize) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    static func image(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func squareImage(from data: Data, pixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0
        else { return nil }

        // The thumbnail limit applies to the long side; size it so the short side still
        // covers the target square after cropping.
        let longSide = max(width, height)
        let shortSide = min(width, height)
        let maxPixelSize = Int((Double(pixelSize) * Double(longSide) / Double(shortSide)).rounded(.up))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        let side = min(thumbnail.width, thumbnail.height)
        let crop = CGRect(
            x: (thumbnail.width - side) / 2,
            y: (thumbnail.height - side) / 2,
            width: side,
            height: side
        )
        return thumbnail.cropping(to: crop)
    }
}
