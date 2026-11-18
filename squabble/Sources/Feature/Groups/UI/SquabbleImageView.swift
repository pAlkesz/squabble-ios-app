import SwiftUI

/// A squabble's picture as a circle, the same crop everywhere it appears: an emoji on its
/// colour, a stored photo, or a picked photo that isn't uploaded yet.
struct SquabbleImageView: View {
    enum Content: Equatable {
        case image(SquabbleImage)
        case local(CGImage)
    }

    let content: Content
    let size: CGFloat

    init(_ image: SquabbleImage, size: CGFloat) {
        self.content = .image(image)
        self.size = size
    }

    init(content: Content, size: CGFloat) {
        self.content = content
        self.size = size
    }

    var body: some View {
        Group {
            switch content {
            case .image(.emoji(let emoji, let color)):
                color.color.overlay {
                    Text(verbatim: emoji)
                        .font(.system(size: size * 0.5))
                }
            case .image(.photo(_, let url)):
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
}
