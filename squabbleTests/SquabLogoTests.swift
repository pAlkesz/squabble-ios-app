import CoreGraphics
import SwiftUI
import Testing
@testable import squabble

struct SquabLogoTests {
    @Test func everyPieceIsAClosedPolygonInsideTheCanvas() {
        for piece in SquabLogoPiece.allCases {
            #expect(piece.polygon.count >= 3)
            for point in piece.polygon {
                #expect(SquabLogoPiece.canvas.contains(point), "\(piece) has \(point) outside the canvas")
            }
            for cutout in piece.cutouts {
                #expect(SquabLogoPiece.canvas.contains(cutout))
            }
        }
    }

    @Test func pivotsLieOnThePiecesThatSwingAroundThem() {
        let receipt = SquabLogoPieceShape(piece: .receipt).path(in: SquabLogoPiece.canvas)
        let wing = SquabLogoPieceShape(piece: .wing).path(in: SquabLogoPiece.canvas)
        #expect(receipt.contains(SquabLogoPiece.beakTip, eoFill: true))
        #expect(wing.contains(SquabLogoPiece.wingJoint, eoFill: true))
    }

    @Test func canvasCornersMapToUnitCorners() {
        let canvas = SquabLogoPiece.canvas
        #expect(SquabLogoPieceShape.anchor(for: CGPoint(x: canvas.minX, y: canvas.minY)) == .topLeading)
        #expect(SquabLogoPieceShape.anchor(for: CGPoint(x: canvas.maxX, y: canvas.maxY)) == .bottomTrailing)
    }

    @Test func pathScalesToFitAnyRectWithoutDistortion() {
        let rect = CGRect(x: 10, y: 20, width: 300, height: 300)
        let drawn = union(of: SquabLogoPiece.allCases.map { SquabLogoPieceShape(piece: $0).path(in: rect).boundingRect })
        let source = union(of: SquabLogoPiece.allCases.map { SquabLogoPieceShape(piece: $0).path(in: SquabLogoPiece.canvas).boundingRect })
        let scale = min(rect.width / SquabLogoPiece.canvas.width, rect.height / SquabLogoPiece.canvas.height)
        #expect(rect.contains(drawn))
        #expect(abs(drawn.width - source.width * scale) < 0.5)
        #expect(abs(drawn.height - source.height * scale) < 0.5)
    }

    private func union(of rects: [CGRect]) -> CGRect {
        rects.reduce(CGRect.null) { $0.union($1) }
    }

    @Test func launchScriptRunsForwardAndEndsDone() {
        let phases = LaunchPhase.script.map(\.phase)
        let times = LaunchPhase.script.map(\.at)
        #expect(phases == phases.sorted())
        #expect(times == times.sorted())
        #expect(phases.last == .done)
    }
}
