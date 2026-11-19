import SwiftUI

/// Every squabble the user is in, most recently active first, laid out like Revolut's
/// conversation list: one card, big pictures, the date on the right. Pushed from home's tile.
struct SquabbleListView: View {
    @Environment(GroupsStore.self) private var groups

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(groups.groups) { group in
                    NavigationLink(value: HomeRoute.squabble(id: group.id)) {
                        SquabbleRow(group: group)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
            .background(.white.opacity(0.08), in: .rect(cornerRadius: SquabbleMetrics.cornerRadius))
            .padding(16)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        // iOS 26's soft fade under the bar; iOS 27 no longer defaults to it.
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(Text("Squabbles", comment: "Home: title of the tile listing the user's squabbles."))
        .navigationBarTitleDisplayMode(.inline)
    }
}
