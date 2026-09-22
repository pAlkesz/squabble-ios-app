import Foundation

/// Everything the user has entered during onboarding, before any of it is saved.
nonisolated struct OnboardingDraft: Equatable {
    private(set) var displayName: String
    private(set) var handle: String
    private(set) var isHandleEdited = false
    var preset: AvatarPreset
    /// A prepared square JPEG; wins over `preset` when set.
    private(set) var photoJPEG: Data?
    /// The upload of `photoJPEG`, kept so a retry after a failed save doesn't upload twice.
    var uploadedPhoto: Avatar?
    var paymentMethods: [PaymentMethod] = []

    init(user: AppUser) {
        displayName = user.displayName ?? ""
        handle = Handle.suggestion(from: displayName)
        preset = .default(for: user.id)
    }

    /// Keeps the handle following the name until the user edits the handle themselves.
    mutating func setDisplayName(_ name: String) {
        displayName = name
        if !isHandleEdited { handle = Handle.suggestion(from: name) }
    }

    mutating func setHandle(_ value: String) {
        handle = value
        isHandleEdited = true
    }

    mutating func setPhoto(_ jpeg: Data?) {
        photoJPEG = jpeg
        uploadedPhoto = nil
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

    /// The avatar to save: the uploaded photo if there is one, otherwise the preset.
    /// Nil while a picked photo still needs uploading.
    var resolvedAvatar: Avatar? {
        guard photoJPEG != nil else { return .preset(preset) }
        return uploadedPhoto
    }

    func profile(for uid: String) -> UserProfile? {
        guard let displayName = validDisplayName,
              case .success(let handle) = validatedHandle,
              let avatar = resolvedAvatar
        else { return nil }
        return UserProfile(id: uid, displayName: displayName, handle: handle, avatar: avatar)
    }
}
