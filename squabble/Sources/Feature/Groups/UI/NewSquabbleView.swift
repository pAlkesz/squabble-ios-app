import FactoryKit
import PhotosUI
import SwiftUI

/// The `+` sheet on home: a picture, a name (or a preset) and a currency. People are added
/// once the squabble exists. Without a photo, creating works offline; a photo has to be
/// uploaded first.
struct NewSquabbleView: View {
    let onCreate: (String) -> Void

    @Injected(\.connectivityMonitor) private var connectivity
    @Environment(GroupsStore.self) private var groups
    @Environment(\.dismiss) private var dismiss
    @State private var draft: NewSquabbleDraft
    @State private var photoPreview: CGImage?
    @State private var path: [Page] = []
    @State private var isShowingLibrary = false
    @State private var isShowingCamera = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var isPreparingPhoto = false
    @State private var isCreating = false
    @State private var isOnline = true
    @State private var failure: String?
    @FocusState private var isNameFocused: Bool

    private enum Page: Hashable {
        case currency
        case emoji
    }

    init(creator: UserProfile, currencyCode: String, onCreate: @escaping (String) -> Void) {
        self.onCreate = onCreate
        _draft = State(initialValue: NewSquabbleDraft(creator: creator, currencyCode: currencyCode))
    }

    var body: some View {
        NavigationStack(path: $path) {
            form
                .navigationDestination(for: Page.self) { page in
                    switch page {
                    case .currency:
                        SquabbleCurrencyPicker(selection: $draft.currencyCode)
                    case .emoji:
                        SquabbleEmojiPicker(emoji: draft.emoji, color: $draft.color) { emoji in
                            draft.setEmoji(emoji)
                            photoPreview = nil
                        }
                    }
                }
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
                Task { await setPhoto(jpeg) }
            }
            .ignoresSafeArea()
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: failure ?? "")
        }
        .task {
            for await isOnline in connectivity.updates() {
                self.isOnline = isOnline
            }
        }
    }

    private var form: some View {
        ScrollView {
            VStack(spacing: 28) {
                imageMenu
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 12) {
                    nameField
                    presets
                }
                currencyRow
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        // iOS 26's soft fade under the bar; iOS 27 no longer defaults to it.
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollDismissesKeyboard(.interactively)
        .foregroundStyle(.white)
        .tint(Color.accent)
        .navigationTitle(Text("Create squabble", comment: "Create squabble sheet: title."))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isCreating {
                    ProgressView()
                } else {
                    Button(role: .confirm) {
                        Task { await create() }
                    }
                    .disabled(!draft.canCreate || isPreparingPhoto)
                }
            }
        }
        .interactiveDismissDisabled(isCreating)
    }

    // MARK: - Picture

    private var imageMenu: some View {
        Menu {
            Button("Choose from library", systemImage: "photo.on.rectangle") {
                isShowingLibrary = true
            }
            if CameraPicker.isAvailable {
                Button("Take a photo", systemImage: "camera") {
                    isShowingCamera = true
                }
            }
            Button(String(localized: "Pick an emoji", comment: "Create squabble: picture menu item that opens the emoji picker."), systemImage: "face.smiling") {
                path.append(.emoji)
            }
            if draft.photoJPEG != nil {
                Button("Remove photo", systemImage: "trash", role: .destructive) {
                    draft.removePhoto()
                    photoPreview = nil
                }
            }
        } label: {
            SquabbleImageView(content: previewContent, size: 120)
                .overlay {
                    if isPreparingPhoto {
                        Circle().fill(.black.opacity(0.35))
                        ProgressView().tint(.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(isPreparingPhoto || isCreating)
        // On the menu, not in its label: the menu morphs its label clipped to the label's
        // bounds, which would cut the overhanging badge on every open and close.
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "camera.fill")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.backdropMid, in: .circle)
                .overlay { Circle().strokeBorder(Color.backdropDeep, lineWidth: 3) }
                .allowsHitTesting(false)
        }
        .accessibilityLabel(Text("Squabble picture", comment: "Create squabble: VoiceOver label for the picture menu."))
    }

    private var previewContent: SquabbleImageView.Content {
        if let photoPreview { return .local(photoPreview) }
        return .image(draft.emojiImage)
    }

    // MARK: - Name

    private var nameField: some View {
        HStack(spacing: 12) {
            TextField(
                "Name",
                text: Binding(get: { draft.name }, set: { draft.setName($0) }),
                prompt: Text("Name your squabble", comment: "Create squabble: placeholder in the name field.")
                    .foregroundStyle(.white.opacity(0.5))
            )
            .focused($isNameFocused)
            .submitLabel(.done)
            .onSubmit { isNameFocused = false }
            if !draft.name.isEmpty {
                Button {
                    draft.setName("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear name", comment: "Create squabble: VoiceOver label for the button that empties the name field."))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 16))
    }

    private var presets: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(SquabblePreset.allCases, id: \.self) { preset in
                    let isSelected = draft.selectedPreset == preset
                    Button {
                        withAnimation(.snappy) { draft.choose(preset) }
                    } label: {
                        Text(verbatim: "\(preset.emoji) \(preset.name)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.backdropDeep : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.white : Color.white.opacity(0.08), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
        // Chips run to the screen edges while lining up with the field above.
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .padding(.horizontal, -16)
    }

    // MARK: - Currency

    private var currencyRow: some View {
        let option = CurrencyOption(code: draft.currencyCode)
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                path.append(.currency)
            } label: {
                HStack(spacing: 14) {
                    CurrencyFlag(option: option, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Currency", comment: "Create squabble: label on the currency row.")
                            .font(.body.weight(.semibold))
                        Text(verbatim: "\(option.code) · \(option.name)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Text("Change", comment: "Create squabble: button on the currency row that opens the currency list.")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.12), in: .capsule)
                }
                .padding(16)
                .background(.white.opacity(0.08), in: .rect(cornerRadius: 20))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            Text("Everyone's balance shows up in this currency.", comment: "Create squabble: note under the currency row.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Actions

    private func loadPicked(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw ProfileError.invalidImage }
            await setPhoto(data)
        } catch {
            failure = error.localizedDescription
        }
    }

    private func setPhoto(_ data: Data) async {
        isPreparingPhoto = true
        defer { isPreparingPhoto = false }
        // Shrinks and crops off the main thread; a camera or library original can be huge.
        let prepared = await Task.detached(priority: .userInitiated) { () -> (Data, CGImage)? in
            guard let jpeg = AvatarImageProcessor.squareJPEG(from: data),
                  let preview = AvatarImageProcessor.image(from: jpeg)
            else { return nil }
            return (jpeg, preview)
        }.value
        guard let (jpeg, preview) = prepared else {
            failure = ProfileError.invalidImage.localizedDescription
            return
        }
        draft.setPhoto(jpeg)
        photoPreview = preview
    }

    private func create() async {
        guard !isCreating else { return }
        if draft.photoJPEG != nil, !isOnline {
            failure = GroupError.photoNeedsInternet.localizedDescription
            return
        }
        isCreating = true
        defer { isCreating = false }
        do {
            let id = try await groups.create(draft)
            dismiss()
            onCreate(id)
        } catch {
            AppLog.error(error, "Squabble creation failed")
            failure = error.localizedDescription
        }
    }
}
