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

    /// The photo's average colour as RGB in 0…1, pushed to a usable strength: an average
    /// is usually a murky grey-brown, which makes a dull backdrop.
    static func backdropColor(from data: Data) -> SIMD3<Double>? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 32,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let average = averageRGB(of: thumbnail)
        else { return nil }
        return vivid(average)
    }

    /// Draws the image into a single pixel and lets the interpolation do the averaging.
    private static func averageRGB(of image: CGImage) -> SIMD3<Double>? {
        var pixel = [UInt8](repeating: 0, count: 4)
        let drawn = pixel.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        guard drawn else { return nil }
        return SIMD3(Double(pixel[0]), Double(pixel[1]), Double(pixel[2])) / 255
    }

    /// Keeps the hue but lifts the saturation and pins the brightness to a range white
    /// text stays readable on.
    static func vivid(_ rgb: SIMD3<Double>) -> SIMD3<Double> {
        let maxComponent = rgb.max()
        let minComponent = rgb.min()
        let delta = maxComponent - minComponent
        let hue: Double
        if delta == 0 {
            hue = 0
        } else if maxComponent == rgb.x {
            hue = ((rgb.y - rgb.z) / delta).truncatingRemainder(dividingBy: 6) / 6
        } else if maxComponent == rgb.y {
            hue = ((rgb.z - rgb.x) / delta + 2) / 6
        } else {
            hue = ((rgb.x - rgb.y) / delta + 4) / 6
        }
        let saturation = maxComponent == 0 ? 0 : delta / maxComponent
        // A grey photo stays grey rather than inventing a red from hue 0.
        let liftedSaturation = saturation < 0.08 ? saturation : max(saturation, 0.55)
        let brightness = min(max(maxComponent, 0.5), 0.7)
        return rgbFrom(hue: (hue + 1).truncatingRemainder(dividingBy: 1), saturation: liftedSaturation, brightness: brightness)
    }

    private static func rgbFrom(hue: Double, saturation: Double, brightness: Double) -> SIMD3<Double> {
        let sector = hue * 6
        let chroma = brightness * saturation
        let x = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let base: SIMD3<Double> = switch Int(sector) % 6 {
        case 0: [chroma, x, 0]
        case 1: [x, chroma, 0]
        case 2: [0, chroma, x]
        case 3: [0, x, chroma]
        case 4: [x, 0, chroma]
        default: [chroma, 0, x]
        }
        return base + SIMD3(repeating: brightness - chroma)
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
