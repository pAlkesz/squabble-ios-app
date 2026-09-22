import PhotosUI
import SwiftUI

struct OnboardingAvatarStep: View {
    @Binding var draft: OnboardingDraft
    let onFailure: (Error) -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var photoPreview: CGImage?
    @State private var isProcessing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            OnboardingHeading(
                title: "Put a face to the debt",
                subtitle: "Pick a bird or use a photo. People pay faster when they can see who's asking."
            )
            preview
                .frame(maxWidth: .infinity)
            presets
            photoButtons
        }
        .task(id: draft.photoJPEG) {
            photoPreview = draft.photoJPEG.flatMap(AvatarImageProcessor.image(from:))
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
    }

    private var preview: some View {
        AvatarView(content: previewContent, size: 168)
            .overlay {
                if isProcessing {
                    Circle().fill(.black.opacity(0.35))
                    ProgressView().tint(.white)
                }
            }
            .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
            .animation(.snappy, value: previewContent)
    }

    private var previewContent: AvatarView.Content {
        if let photoPreview, draft.photoJPEG != nil { return .local(photoPreview) }
        return .avatar(.preset(draft.preset))
    }

    private var presets: some View {
        HStack(spacing: 12) {
            ForEach(AvatarPreset.allCases, id: \.self) { preset in
                let isSelected = draft.photoJPEG == nil && draft.preset == preset
                Button {
                    draft.preset = preset
                    draft.setPhoto(nil)
                    pickerItem = nil
                } label: {
                    AvatarView(.preset(preset), size: 52)
                        .padding(3)
                        .overlay {
                            Circle().strokeBorder(.white, lineWidth: isSelected ? 3 : 0)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(preset.accessibilityName))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: draft.preset)
    }

    private var photoButtons: some View {
        HStack(spacing: 12) {
            // PhotosPicker's label closure is @Sendable, so capture a plain Bool, not `draft`.
            let hasPhoto = draft.photoJPEG != nil
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label(hasPhoto ? "Choose another" : "Use a photo", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            if draft.photoJPEG != nil {
                Button("Remove photo", systemImage: "xmark") {
                    draft.setPhoto(nil)
                    pickerItem = nil
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .controlSize(.large)
            }
        }
        .disabled(isProcessing)
    }

    private func load(_ item: PhotosPickerItem) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw ProfileError.invalidImage }
            let jpeg = await Task.detached(priority: .userInitiated) {
                AvatarImageProcessor.squareJPEG(from: data)
            }.value
            guard let jpeg else { throw ProfileError.invalidImage }
            draft.setPhoto(jpeg)
        } catch {
            pickerItem = nil
            onFailure(error)
        }
    }
}
