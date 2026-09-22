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
