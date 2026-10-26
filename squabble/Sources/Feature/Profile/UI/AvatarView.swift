import SwiftUI

/// A round avatar: the bird or a persona on a coloured disc, a stored photo, a photo
/// that hasn't been uploaded yet, or an empty disc while one is still being prepared.
struct AvatarView: View {
    enum Content: Equatable {
        case avatar(Avatar)
        case local(CGImage)
        case empty
    }

    let content: Content
    let size: CGFloat
    /// Round by default; a corner radius makes it a square photo, as on an ID card.
    let cornerRadius: CGFloat?

    init(_ avatar: Avatar, size: CGFloat, cornerRadius: CGFloat? = nil) {
        self.content = .avatar(avatar)
        self.size = size
        self.cornerRadius = cornerRadius
    }

    init(content: Content, size: CGFloat, cornerRadius: CGFloat? = nil) {
        self.content = content
        self.size = size
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            switch content {
            case .avatar(.preset(let preset)):
                bird(on: preset)
            case .avatar(.persona(let persona, let color)):
                color.color.overlay {
                    Image(persona.image).resizable().scaledToFill()
                }
            case .avatar(.photo(_, let url)):
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.backdropMid.overlay { ProgressView().tint(.white) }
                    }
                }
            case .local(let image):
                Image(decorative: image, scale: 1).resizable().scaledToFill()
            case .empty:
                Color.backdropMid
            }
        }
        .frame(width: size, height: size)
        .clipShape(cornerRadius.map { AnyShape(.rect(cornerRadius: $0)) } ?? AnyShape(.circle))
        .accessibilityHidden(true)
    }

    private func bird(on preset: AvatarColor) -> some View {
        preset.color
            .overlay {
                SquabLogoView()
                    .padding(size * 0.2)
            }
    }
}

#Preview {
    HStack {
        ForEach(AvatarColor.allCases, id: \.self) { preset in
            AvatarView(.preset(preset), size: 56)
        }
    }
    .padding()
    .background(Color.backdropDeep)
}
