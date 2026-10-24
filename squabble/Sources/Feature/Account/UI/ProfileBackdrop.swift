import SwiftUI

/// The account pages' background: `SquabbleBackdrop` in the colour of the user's avatar —
/// the persona's disc, or the main colour of their photo — rather than home's balance mood.
/// These pages are about the person, not their debts.
struct ProfileBackdrop: View {
    @Environment(AuthSession.self) private var session
    @State private var photoColor: Color?

    var body: some View {
        SquabbleBackdrop(palette: palette)
            .animation(.smooth(duration: 0.8), value: palette)
            .task(id: session.profile?.avatar) { await loadPhotoColor() }
    }

    private var palette: BackdropPalette {
        switch session.profile?.avatar {
        case .preset(let color), .persona(_, let color): .tinted(color.color)
        case .photo: photoColor.map(BackdropPalette.tinted) ?? .brand
        case nil: .brand
        }
    }

    /// Reads the photo through the shared URL cache, which `AvatarView` has usually filled
    /// already, so this rarely costs a download.
    private func loadPhotoColor() async {
        guard case .photo(_, let url) = session.profile?.avatar else {
            photoColor = nil
            return
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        let rgb = await Task.detached(priority: .utility) {
            AvatarImageProcessor.backdropColor(from: data)
        }.value
        photoColor = rgb.map { Color(red: $0.x, green: $0.y, blue: $0.z) }
    }
}
