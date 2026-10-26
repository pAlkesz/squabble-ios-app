import CoreImage
import CoreImage.CIFilterBuiltins

/// A Code 128 barcode as its row of modules (`true` is a bar), so the card can draw it
/// in its own ink at any size. Core Image does the encoding.
nonisolated enum Code128Barcode {
    static func modules(for text: String) -> [Bool]? {
        guard let message = text.data(using: .ascii), !message.isEmpty else { return nil }
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = message
        filter.quietSpace = 0
        filter.barcodeHeight = 1
        guard let output = filter.outputImage else { return nil }

        let width = Int(output.extent.width)
        var row = [UInt8](repeating: 0, count: width * 4)
        CIContext(options: [.useSoftwareRenderer: true]).render(
            output,
            toBitmap: &row,
            rowBytes: width * 4,
            bounds: CGRect(x: output.extent.minX, y: output.extent.minY, width: CGFloat(width), height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        return (0..<width).map { row[$0 * 4] < 128 }
    }
}
