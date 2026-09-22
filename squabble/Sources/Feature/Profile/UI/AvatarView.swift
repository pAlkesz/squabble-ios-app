import SwiftUI

/// A round avatar: the bird on a coloured disc, a stored photo, or a photo that hasn't
/// been uploaded yet.
struct AvatarView: View {
    enum Content: Equatable {
        case avatar(Avatar)
        case local(CGImage)
    }

    let content: Content
    let size: CGFloat

    init(_ avatar: Avatar, size: CGFloat) {
        self.content = .avatar(avatar)
        self.size = size
    }

    init(content: Content, size: CGFloat) {
        self.content = content
        self.size = size
    }

    var body: some View {
        Group {
            switch content {
            case .avatar(.preset(let preset)):
                bird(on: preset)
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
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }

    private func bird(on preset: AvatarPreset) -> some View {
        preset.color
            .overlay {
                SquabLogoView()
                    .padding(size * 0.2)
            }
    }
}

#Preview {
    HStack {
        ForEach(AvatarPreset.allCases, id: \.self) { preset in
            AvatarView(.preset(preset), size: 56)
        }
    }
    .padding()
    .background(Color.backdropDeep)
}
