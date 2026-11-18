import Foundation

/// Everything entered on the create-squabble sheet, before anything is saved. People are
/// added after it exists, so a new squabble starts with its creator alone.
nonisolated struct NewSquabbleDraft: Equatable {
    let creator: UserProfile
    private(set) var name = ""
    var currencyCode: String
    /// Shown whenever there's no photo, and kept while there is one, so removing the photo
    /// goes back to it.
    private(set) var emoji: String
    var color: AvatarColor
    /// A prepared square JPEG, uploaded only when the squabble is created.
    private(set) var photoJPEG: Data?

    init(creator: UserProfile, currencyCode: String, emoji: SquabbleImage = .random()) {
        self.creator = creator
        self.currencyCode = currencyCode
        if case .emoji(let symbol, let color) = emoji {
            self.emoji = symbol
            self.color = color
        } else {
            self.emoji = SquabbleImage.emojis[0]
            self.color = .meadow
        }
    }

    var validName: String? {
        SquabbleGroup.validName(name)
    }

    var canCreate: Bool {
        validName != nil
    }

    /// The preset whose name is in the field, if any; its chip shows as selected.
    var selectedPreset: SquabblePreset? {
        SquabblePreset.allCases.first { $0.name == validName }
    }

    mutating func setName(_ input: String) {
        name = String(input.prefix(SquabbleGroup.maxNameLength))
    }

    /// Fills in the preset's name and emoji; a chosen photo stays.
    mutating func choose(_ preset: SquabblePreset) {
        name = preset.name
        emoji = preset.emoji
    }

    /// Picking an emoji means not wanting the photo any more.
    mutating func setEmoji(_ symbol: String) {
        emoji = symbol
        photoJPEG = nil
    }

    mutating func setPhoto(_ jpeg: Data) {
        photoJPEG = jpeg
    }

    mutating func removePhoto() {
        photoJPEG = nil
    }

    var emojiImage: SquabbleImage {
        .emoji(emoji, color)
    }

    /// The squabble to save, with its creator as the only member. `photo` is the uploaded
    /// photo when there is one; otherwise it gets the emoji.
    func makeGroup(id: String, photo: SquabbleImage? = nil, creatorPaymentMethods: [PaymentMethod]) -> SquabbleGroup? {
        guard let name = validName else { return nil }
        let creatorEntry = GroupMember(profile: creator, paymentMethods: creatorPaymentMethods)
        return SquabbleGroup(
            id: id,
            name: name,
            currencyCode: currencyCode,
            image: photo ?? emojiImage,
            createdBy: creator.id,
            memberIds: [creator.id],
            members: [creator.id: creatorEntry]
        )
    }
}
