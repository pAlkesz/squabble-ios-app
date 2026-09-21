import CoreGraphics

/// The paper-cut pieces that make up the Squabble bird, traced from the app icon.
///
/// Coordinates are in the icon's 1024×1024 space; `canvas` is the region the bird
/// occupies, which `SquabLogoPieceShape` maps into whatever rect it's given.
/// Cases are declared bottom-to-top in draw order.
nonisolated enum SquabLogoPiece: CaseIterable, Sendable {
    case tailLower
    case tailUpper
    case wing
    case body
    case receipt
    case receiptCurl

    static let canvas = CGRect(x: 140, y: 240, width: 750, height: 525)

    static var aspectRatio: CGFloat { canvas.width / canvas.height }

    /// Where the receipt hangs from the beak — receipt pieces pivot here.
    static let beakTip = CGPoint(x: 748, y: 304)

    /// Where the wing joins the body — the wing pivots here when it flaps.
    static let wingJoint = CGPoint(x: 575, y: 500)

    var polygon: [CGPoint] {
        switch self {
        case .body:
            [
                CGPoint(x: 555, y: 308), CGPoint(x: 559, y: 442), CGPoint(x: 643, y: 563),
                CGPoint(x: 499, y: 716), CGPoint(x: 550, y: 650), CGPoint(x: 472, y: 678),
                CGPoint(x: 361, y: 696), CGPoint(x: 495, y: 721), CGPoint(x: 612, y: 699),
                CGPoint(x: 687, y: 650), CGPoint(x: 731, y: 576), CGPoint(x: 705, y: 370),
                CGPoint(x: 665, y: 371), CGPoint(x: 723, y: 331), CGPoint(x: 755, y: 325),
                CGPoint(x: 746, y: 310), CGPoint(x: 693, y: 314), CGPoint(x: 780, y: 266),
                CGPoint(x: 808, y: 264), CGPoint(x: 778, y: 250), CGPoint(x: 706, y: 275),
                CGPoint(x: 650, y: 251), CGPoint(x: 598, y: 257),
            ]
        case .receipt:
            [
                CGPoint(x: 738, y: 299), CGPoint(x: 756, y: 311), CGPoint(x: 764, y: 328),
                CGPoint(x: 776, y: 391), CGPoint(x: 786, y: 402), CGPoint(x: 807, y: 408),
                CGPoint(x: 814, y: 392), CGPoint(x: 809, y: 379), CGPoint(x: 840, y: 364),
                CGPoint(x: 821, y: 342), CGPoint(x: 807, y: 296), CGPoint(x: 782, y: 285),
            ]
        case .receiptCurl:
            [
                CGPoint(x: 819, y: 406), CGPoint(x: 869, y: 379), CGPoint(x: 880, y: 353),
                CGPoint(x: 818, y: 381),
            ]
        case .wing:
            [
                CGPoint(x: 209, y: 707), CGPoint(x: 496, y: 660), CGPoint(x: 568, y: 630),
                CGPoint(x: 630, y: 562), CGPoint(x: 548, y: 446), CGPoint(x: 396, y: 517),
            ]
        case .tailUpper:
            [
                CGPoint(x: 206, y: 694), CGPoint(x: 281, y: 618), CGPoint(x: 149, y: 622),
                CGPoint(x: 172, y: 638), CGPoint(x: 168, y: 654), CGPoint(x: 188, y: 664),
                CGPoint(x: 184, y: 680),
            ]
        case .tailLower:
            [
                CGPoint(x: 215, y: 717), CGPoint(x: 237, y: 753), CGPoint(x: 244, y: 741),
                CGPoint(x: 263, y: 752), CGPoint(x: 269, y: 740), CGPoint(x: 288, y: 749),
                CGPoint(x: 296, y: 738), CGPoint(x: 315, y: 748), CGPoint(x: 321, y: 736),
                CGPoint(x: 339, y: 745), CGPoint(x: 348, y: 734), CGPoint(x: 366, y: 742),
                CGPoint(x: 343, y: 698),
            ]
        }
    }

    /// Elliptical holes punched out of the piece (the eye).
    var cutouts: [CGRect] {
        switch self {
        case .body: [CGRect(x: 630, y: 285, width: 22, height: 22)]
        default: []
        }
    }
}
