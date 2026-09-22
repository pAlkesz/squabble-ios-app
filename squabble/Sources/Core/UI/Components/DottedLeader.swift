import SwiftUI

/// The run of dots between a receipt's label and its amount.
struct DottedLeader: View {
    var body: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [1, 3]))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 3)
    }
}

private nonisolated struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
