import PhotosUI
import SwiftUI

/// The big preview with its slogan, then a grid of everything to pick from: a glass
/// "add photo" tile, the user's own photo once there is one, then the personas.
struct OnboardingAvatarStep: View {
    @Binding var draft: OnboardingDraft
    let onFailure: (Error) -> Void

    @State private var photoPreview: CGImage?
    @State private var isProcessing = false
    @State private var isChoosingSource = false
    @State private var pendingSource: AvatarPhotoSourceSheet.Source?
    @State private var isShowingLibrary = false
    @State private var isShowingCamera = false
    @State private var pickerItem: PhotosPickerItem?

    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    private static let tileSize: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            OnboardingHeading(
                title: "Put a face to the debt",
                subtitle: "Pick who you'll be when the bill comes. Or show your actual face — people pay faster when they can see who's asking."
            )
            selection
                .frame(maxWidth: .infinity)
            grid
        }
        .task(id: draft.photoJPEG) {
            photoPreview = draft.photoJPEG.flatMap(AvatarImageProcessor.image(from:))
        }
        .sheet(isPresented: $isChoosingSource, onDismiss: openPendingSource) {
            AvatarPhotoSourceSheet { pendingSource = $0 }
        }
        .photosPicker(isPresented: $isShowingLibrary, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await loadPicked(item) }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { jpeg in
                isShowingCamera = false
                guard let jpeg else { return }
                Task { await prepare(jpeg) }
            }
            .ignoresSafeArea()
        }
        .sensoryFeedback(.selection, trigger: draft.avatarChoice)
    }

    // MARK: - Selection

    private var selection: some View {
        VStack(spacing: 16) {
            AvatarView(content: content(for: draft.avatarChoice), size: 168)
                .overlay {
                    if isProcessing {
                        Circle().fill(.black.opacity(0.35))
                        ProgressView().tint(.white)
                    }
                }
                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
            // At least two lines tall, so switching between a one- and a two-line slogan
            // doesn't shift the grid. A hidden placeholder rather than
            // `lineLimit(2, reservesSpace:)`, which would also cap it at two lines and
            // truncate the joke at large accessibility sizes.
            ZStack(alignment: .top) {
                Text(verbatim: "\n")
                    .hidden()
                Text(caption(for: draft.avatarChoice))
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
            }
            .font(.title3.weight(.semibold).italic())
        }
        .animation(.snappy, value: draft.avatarChoice)
    }

    // MARK: - Grid

    private var choices: [OnboardingDraft.AvatarChoice] {
        (photoPreview == nil ? [] : [.photo]) + draft.avatarOptions
    }

    private var grid: some View {
        LazyVGrid(columns: Self.columns, spacing: 12) {
            addPhotoTile
            ForEach(choices, id: \.self) { choice in
                tile(for: choice)
            }
        }
    }

    private var addPhotoTile: some View {
        Button {
            isChoosingSource = true
        } label: {
            Image(systemName: "photo.badge.plus")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: Self.tileSize, height: Self.tileSize)
                .glassEffect(.regular.interactive(), in: .circle)
                .padding(3)
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
        .accessibilityLabel(Text("Add a photo", comment: "Avatar photo source sheet: title."))
    }

    private func tile(for choice: OnboardingDraft.AvatarChoice) -> some View {
        let isSelected = draft.avatarChoice == choice
        return Button {
            draft.choose(choice)
        } label: {
            AvatarView(content: content(for: choice), size: Self.tileSize)
                .padding(3)
                .overlay {
                    Circle().strokeBorder(.white, lineWidth: isSelected ? 3 : 0)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(caption(for: choice)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func content(for choice: OnboardingDraft.AvatarChoice) -> AvatarView.Content {
        switch choice {
        case .persona(let persona, let color): .avatar(.persona(persona, color))
        case .photo: photoPreview.map(AvatarView.Content.local) ?? .empty
        }
    }

    private func caption(for choice: OnboardingDraft.AvatarChoice) -> String {
        switch choice {
        case .persona(let persona, _):
            persona.slogan
        case .photo:
            String(
                localized: "Arccal és névvel vállalom",
                comment: "Avatar caption for the user's own photo. A Hungarian pop culture reference, deliberately the same in every language."
            )
        }
    }

    // MARK: - Adding a photo

    private func openPendingSource() {
        switch pendingSource {
        case .library: isShowingLibrary = true
        case .camera: isShowingCamera = true
        case nil: break
        }
        pendingSource = nil
    }

    private func loadPicked(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw ProfileError.invalidImage }
            await prepare(data)
        } catch {
            onFailure(error)
        }
    }

    /// Shrinks and crops off the main thread; a camera or library original can be huge.
    private func prepare(_ data: Data) async {
        isProcessing = true
        defer { isProcessing = false }
        let jpeg = await Task.detached(priority: .userInitiated) {
            AvatarImageProcessor.squareJPEG(from: data)
        }.value
        guard let jpeg else {
            onFailure(ProfileError.invalidImage)
            return
        }
        draft.setPhoto(jpeg)
    }
}
