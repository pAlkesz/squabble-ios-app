import Foundation

/// Everything the user has entered during onboarding, before any of it is saved.
nonisolated struct OnboardingDraft: Equatable {
    /// The plain bird is no longer offered; it survives only as `Avatar.preset`, for
    /// profiles that already have it and as the fallback for an unreadable avatar.
    enum AvatarChoice: Hashable {
        case persona(AvatarPersona, AvatarColor)
        case photo
    }

    private(set) var displayName: String
    private(set) var handle: String
    private(set) var isHandleEdited = false
    /// Every persona, each already on its colour; see `dealOptions`.
    let avatarOptions: [AvatarChoice]
    private(set) var avatarChoice: AvatarChoice
    /// A prepared square JPEG. Kept while another avatar is chosen, so switching back
    /// doesn't mean picking it again.
    private(set) var photoJPEG: Data?
    /// The upload of `photoJPEG`, kept so a retry after a failed save doesn't upload twice.
    var uploadedPhoto: Avatar?
    var paymentMethods: [PaymentMethod] = []

    init(user: AppUser) {
        displayName = user.displayName ?? ""
        handle = Handle.suggestion(from: displayName)
        avatarOptions = Self.dealOptions()
        // A random one, so even a user who skips past the step ends up with some character.
        avatarChoice = avatarOptions.randomElement() ?? .persona(.bigSpender, .meadow)
    }

    /// The personas, coloured from a shuffled palette dealt out in order:
    /// every tile gets a colour of its own while there are enough colours to go round.
    /// If personas ever outnumber them, colours repeat only every `allCases.count` tiles,
    /// which in a four-wide grid still never matches a tile's neighbours.
    static func dealOptions() -> [AvatarChoice] {
        let palette = AvatarColor.allCases.shuffled()
        return AvatarPersona.allCases.enumerated().map { index, persona in
            .persona(persona, palette[index % palette.count])
        }
    }

    /// Keeps the handle following the name until the user edits the handle themselves.
    /// Anything past the length limit is dropped, so the draft never holds an over-long
    /// value — not even for a moment.
    mutating func setDisplayName(_ name: String) {
        displayName = String(name.prefix(UserProfile.maxDisplayNameLength))
        if !isHandleEdited { handle = Handle.suggestion(from: displayName) }
    }

    mutating func setHandle(_ value: String) {
        handle = String(value.prefix(Handle.lengthRange.upperBound))
        isHandleEdited = true
    }

    /// Choosing `.photo` without a photo does nothing; there'd be nothing to show.
    mutating func choose(_ choice: AvatarChoice) {
        guard choice != .photo || photoJPEG != nil else { return }
        avatarChoice = choice
    }

    /// A new photo is also chosen straight away — the user just went to the trouble.
    mutating func setPhoto(_ jpeg: Data) {
        photoJPEG = jpeg
        uploadedPhoto = nil
        avatarChoice = .photo
    }

    /// The photo to upload before saving, if the chosen avatar needs one.
    var photoToUpload: Data? {
        guard avatarChoice == .photo, uploadedPhoto == nil else { return nil }
        return photoJPEG
    }

    var validDisplayName: String? {
        UserProfile.validDisplayName(displayName)
    }

    var validatedHandle: Result<Handle, HandleError> {
        Result { () throws(HandleError) in try Handle(validating: handle) }
    }

    var canAddPaymentMethod: Bool {
        paymentMethods.count < PaymentMethod.maxCount
    }

    /// The avatar to save. Nil while a chosen photo still needs uploading.
    var resolvedAvatar: Avatar? {
        switch avatarChoice {
        case .persona(let persona, let color): .persona(persona, color)
        case .photo: uploadedPhoto
        }
    }

    func profile(for uid: String) -> UserProfile? {
        guard let displayName = validDisplayName,
              case .success(let handle) = validatedHandle,
              let avatar = resolvedAvatar
        else { return nil }
        return UserProfile(id: uid, displayName: displayName, handle: handle, avatar: avatar)
    }
}
