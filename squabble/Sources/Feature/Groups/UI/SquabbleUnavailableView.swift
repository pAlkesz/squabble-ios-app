import SwiftUI

/// Shown in place of a squabble that's no longer readable: deleted, or the user left it.
struct SquabbleUnavailableView: View {
    var body: some View {
        ContentUnavailableView {
            Label {
                Text("This squabble is gone", comment: "Squabble page: the squabble no longer exists or the user left it.")
            } icon: {
                Image(systemName: "bird")
            }
        } description: {
            Text("Someone deleted it, or you're no longer in it.", comment: "Squabble page: explanation when the squabble is gone.")
        }
    }
}
