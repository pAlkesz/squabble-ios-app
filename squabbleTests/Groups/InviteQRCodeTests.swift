import CoreImage
import SwiftUI
import Testing
@testable import squabble

@MainActor
struct InviteQRCodeTests {
    /// The dots, the rounded finders and the picture over the middle must still scan.
    @Test(arguments: [SquabbleImage.artwork(.trio, .dusk), .artwork(.suits, .sand)])
    func styledCodeStillScans(image: SquabbleImage) throws {
        let link = "https://squabble-9c1df.web.app/join/Ab3_-xYz1234567890abcd"
        let matrix = try #require(QRMatrix(link))
        let view = InviteQRCode(matrix: matrix, image: image, size: 300)
            .padding(30)
            .background(Color.backdropDeep)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let cgImage = try #require(renderer.cgImage)
        let detector = try #require(CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]))
        let features = detector.features(in: CIImage(cgImage: cgImage)).compactMap { $0 as? CIQRCodeFeature }
        #expect(features.first?.messageString == link)
    }
}
