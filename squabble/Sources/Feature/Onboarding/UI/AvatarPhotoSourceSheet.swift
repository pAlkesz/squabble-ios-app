import SwiftUI

/// Asks where a new avatar photo should come from. It only reports the choice; the
/// caller opens the picker once the sheet is gone, since two modals can't present at once.
struct AvatarPhotoSourceSheet: View {
    enum Source {
        case library
        case camera
    }

    let onChoose: (Source) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Add a photo", comment: "Avatar photo source sheet: title.")
                    .font(.title2.bold())
                Text(
                    "Your face, your rules. Mostly your face.",
                    comment: "Avatar photo source sheet: subtitle."
                )
                .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            // Default spacing plus 4, matching the ThermalGlass sheets' button pair.
            VStack {
                SquabbleGlassButton(
                    title: "Choose from library",
                    systemImage: "photo.on.rectangle",
                    kind: .prominent
                ) {
                    choose(.library)
                }
                .padding(.bottom, 4)
                if CameraPicker.isAvailable {
                    SquabbleGlassButton(title: "Take a photo", systemImage: "camera") {
                        choose(.camera)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 8)
        .frame(maxWidth: 480)
        .fittedSheet()
    }

    private func choose(_ source: Source) {
        onChoose(source)
        dismiss()
    }
}
