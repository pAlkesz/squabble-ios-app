import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import squabble

struct AvatarImageProcessorTests {
    @Test(arguments: [(2000, 1200), (900, 1600), (512, 512)])
    func producesASquareJPEGAtTheTargetSize(width: Int, height: Int) throws {
        let jpeg = try #require(AvatarImageProcessor.squareJPEG(from: try pngData(width: width, height: height)))
        let image = try #require(AvatarImageProcessor.image(from: jpeg))
        #expect(image.width == image.height)
        #expect(image.width == AvatarImageProcessor.pixelSize)
    }

    @Test func doesNotUpscaleSmallImages() throws {
        let jpeg = try #require(AvatarImageProcessor.squareJPEG(from: try pngData(width: 300, height: 200)))
        let image = try #require(AvatarImageProcessor.image(from: jpeg))
        #expect(image.width == 200)
        #expect(image.height == 200)
    }

    @Test func rejectsNonImageData() {
        #expect(AvatarImageProcessor.squareJPEG(from: Data("not an image".utf8)) == nil)
    }

    private func pngData(width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.1, green: 0.6, blue: 0.3, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }
}

struct AvatarBackdropColorTests {
    @Test func murkyColoursGetVivid() {
        let brown = AvatarImageProcessor.vivid([0.45, 0.38, 0.32])
        let saturation = (brown.max() - brown.min()) / brown.max()
        #expect(saturation >= 0.54)
        #expect(brown.x > brown.y && brown.y > brown.z)
    }

    @Test func greyStaysGrey() {
        let grey = AvatarImageProcessor.vivid([0.2, 0.2, 0.2])
        #expect(grey.max() - grey.min() < 0.001)
        #expect(grey.max() >= 0.5)
    }

    @Test func brightnessIsCappedForWhiteText() {
        #expect(AvatarImageProcessor.vivid([1, 0.9, 0.2]).max() <= 0.7 + 1e-9)
    }
}
