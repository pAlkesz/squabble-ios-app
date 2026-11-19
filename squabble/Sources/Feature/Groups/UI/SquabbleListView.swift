import SwiftUI

/// Every squabble the user is in, most recently active first, laid out like Revolut's
/// conversation list: one card, big pictures, the date on the right. Pushed from home's tile.
struct SquabbleListView: View {
    /// Home's, so the create sheet it presents can zoom out of this page's `+`.
    let transitions: Namespace.ID
    let onNewSquabble: () -> Void

    @Environment(GroupsStore.self) private var groups
    @Environment(AuthSession.self) private var session

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // A styled label: toolbar buttons take the accent colour and ignore `.tint`.
                Button(action: onNewSquabble) {
                    Image(systemName: "plus")
                        .foregroundStyle(.white)
                }
                .disabled(session.profile == nil)
                .accessibilityLabel("New squabble")
            }
            .matchedTransitionSource(id: NewSquabbleSource.listToolbar, in: transitions)
        }
    }
}
