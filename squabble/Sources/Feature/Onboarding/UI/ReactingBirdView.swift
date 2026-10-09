import SwiftUI

/// The logo bird as a spectator: it nods when a handle comes back free and shakes its
/// head when it's taken. The whole mark moves — shifting pieces on their own tears the
/// silhouette apart. Reduce Motion keeps it still.
struct ReactingBirdView: View {
    let nodTrigger: Int
    let shakeTrigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Captured up front: keyframe closures are Sendable and can't read the environment.
        let isStill = reduceMotion
        SquabLogoView(color: .white)
            .keyframeAnimator(initialValue: Angle.zero, trigger: nodTrigger) { content, angle in
                content.rotationEffect(isStill ? .zero : angle, anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack {
                    SpringKeyframe(.degrees(14), duration: 0.16)
                    SpringKeyframe(.degrees(-4), duration: 0.18)
                    SpringKeyframe(.degrees(8), duration: 0.16)
                    SpringKeyframe(.zero, duration: 0.22)
                }
            }
            .keyframeAnimator(initialValue: CGFloat.zero, trigger: shakeTrigger) { content, offset in
                content.offset(x: isStill ? 0 : offset)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(-7, duration: 0.06)
                    LinearKeyframe(7, duration: 0.09)
                    LinearKeyframe(-5, duration: 0.09)
                    LinearKeyframe(4, duration: 0.08)
                    LinearKeyframe(0, duration: 0.07)
                }
            }
            .accessibilityHidden(true)
    }
}
