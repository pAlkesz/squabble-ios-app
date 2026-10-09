import SwiftUI

extension View {
    /// Presents this view in place by growing it out of `source` — a frame in the shared
    /// coordinate space of this view and whatever presents it, both filling the same area.
    /// The element marked `zoomDestination()` inside starts exactly on top of `source`, so
    /// e.g. an avatar seems to swell into the screen around it. Stays mounted while hidden
    /// (invisible, untouchable, hidden from VoiceOver) so its geometry is always known.
    /// Drive `isPresented` with `.zoomPresentation`.
    func zoomPresentation(isPresented: Bool, from source: CGRect) -> some View {
        modifier(ZoomPresentation(isPresented: isPresented, source: source))
    }

    /// Marks where a `zoomPresentation` lands; its frame is what grows out of the source.
    func zoomDestination() -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: ZoomDestinationKey.self,
                    value: proxy.frame(in: .named(ZoomPresentation.space))
                )
            }
        }
    }

    /// The screen behind a `zoomPresentation`: blurred out of focus and dimmed while it's up.
    func zoomPresentationBackdrop(isActive: Bool) -> some View {
        blur(radius: isActive ? 28 : 0)
            .overlay {
                Color.black
                    .opacity(isActive ? 0.25 : 0)
                    .ignoresSafeArea()
            }
            .allowsHitTesting(!isActive)
            .accessibilityHidden(isActive)
    }
}

extension Animation {
    /// Quick to arrive with a short settle, like the zoom it drives.
    static let zoomPresentation = Animation.spring(duration: 0.38, bounce: 0.1)
}

private struct ZoomPresentation: ViewModifier {
    static let space = "zoomPresentation"

    let isPresented: Bool
    let source: CGRect

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var destination: CGRect?
    @State private var size: CGSize = .zero

    func body(content: Content) -> some View {
        content
            // Measured inside the transforms below, so it's the destination's resting frame.
            .coordinateSpace(.named(Self.space))
            .onPreferenceChange(ZoomDestinationKey.self) { destination = $0 }
            .onGeometryChange(for: CGSize.self, of: \.size) { size = $0 }
            // Visual effects leave layout alone, so the destination measures the same mid-zoom
            // as at rest; layout transforms would feed back into the measurement and loop.
            .visualEffect { [isPresented, reduceMotion, collapsed] content, _ in
                content
                    .blur(radius: isPresented || reduceMotion ? 0 : 10)
                    .scaleEffect(isPresented ? 1 : collapsed.scale, anchor: collapsed.anchor)
                    .offset(isPresented ? .zero : collapsed.offset)
            }
            // Turns solid well before it finishes growing, and vanishes early on the way back.
            .animation(.easeOut(duration: 0.16)) {
                $0.opacity(isPresented ? 1 : 0)
            }
            .allowsHitTesting(isPresented)
            .accessibilityHidden(!isPresented)
            .accessibilityAddTraits(isPresented ? .isModal : [])
    }

    /// The collapsed pose: scaled around the destination's centre and moved onto the source.
    private var collapsed: (scale: CGFloat, anchor: UnitPoint, offset: CGSize) {
        guard !reduceMotion, let destination, destination.width > 0, size.width > 0, size.height > 0,
              source.width > 0
        else {
            return (reduceMotion ? 1 : 0.9, .center, .zero)
        }
        return (
            min(max(source.width / destination.width, 0.05), 1),
            UnitPoint(x: destination.midX / size.width, y: destination.midY / size.height),
            CGSize(width: source.midX - destination.midX, height: source.midY - destination.midY)
        )
    }
}

private struct ZoomDestinationKey: PreferenceKey {
    static let defaultValue: CGRect? = nil

    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        value = value ?? nextValue()
    }
}
