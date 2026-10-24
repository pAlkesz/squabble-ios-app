import SwiftUI

/// The height chart from a police lineup, drawn behind the profile header: your profile is
/// what people see when you chase them for money, so it might as well be a mugshot. Marks
/// are in centimetres, or feet and inches where the locale measures people that way.
struct LineupChart: View {
    private let scale = Scale.current

    var body: some View {
        Canvas { context, size in
            let pointsPerUnit = size.height / Double(scale.range.count - 1)
            for value in scale.range where value.isMultiple(of: scale.minorStep) {
                let y = Double(scale.range.upperBound - value) * pointsPerUnit
                let isMajor = value.isMultiple(of: scale.majorStep)
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(.white.opacity(isMajor ? 0.28 : 0.1)), lineWidth: isMajor ? 1.5 : 1)
                guard isMajor else { continue }
                let label = context.resolve(
                    Text(verbatim: scale.label(for: value))
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.45))
                )
                context.draw(label, at: CGPoint(x: 8, y: y - 2), anchor: .bottomLeading)
                context.draw(label, at: CGPoint(x: size.width - 8, y: y - 2), anchor: .bottomTrailing)
            }
        }
        .accessibilityHidden(true)
    }

    private struct Scale {
        let range: ClosedRange<Int>
        let minorStep: Int
        let majorStep: Int
        let unit: UnitLength

        static var current: Scale {
            if Locale.current.measurementSystem == .us {
                Scale(range: 54...78, minorStep: 1, majorStep: 6, unit: .inches)
            } else {
                Scale(range: 140...200, minorStep: 5, majorStep: 10, unit: .centimeters)
            }
        }

        func label(for value: Int) -> String {
            Measurement(value: Double(value), unit: unit)
                .formatted(.measurement(width: .narrow, usage: .personHeight))
        }
    }
}
