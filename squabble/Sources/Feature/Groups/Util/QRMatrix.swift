import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// A QR code's modules, read out of Core Image's generator so the code can be drawn in our
/// own style (dots and rounded finders) rather than as a bitmap.
nonisolated struct QRMatrix: Equatable, Sendable {
    let size: Int
    private let modules: [Bool]

    /// High error correction, so a picture over the centre doesn't stop it scanning.
    init?(_ text: String) {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "H"
        guard let output = filter.outputImage,
              let image = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        // The generator pads the code with a quiet zone; keep just the modules.
        let dark = pixels.indices.filter { pixels[$0] < 128 }
        guard let first = dark.first, let last = dark.last else { return nil }
        let origin = (x: first % width, y: first / width)
        let side = last / width - origin.y + 1
        guard side > 0 else { return nil }
        var modules = [Bool](repeating: false, count: side * side)
        for y in 0..<side {
            for x in 0..<side {
                modules[y * side + x] = pixels[(origin.y + y) * width + origin.x + x] < 128
            }
        }
        self.size = side
        self.modules = modules
    }

    func isDark(x: Int, y: Int) -> Bool {
        guard (0..<size).contains(x), (0..<size).contains(y) else { return false }
        return modules[y * size + x]
    }

    /// Inside one of the three 7×7 finder squares, which are drawn separately.
    func isFinder(x: Int, y: Int) -> Bool {
        let near = 0..<7, far = (size - 7)..<size
        return (near.contains(x) && near.contains(y)) || (far.contains(x) && near.contains(y)) || (near.contains(x) && far.contains(y))
    }
}
