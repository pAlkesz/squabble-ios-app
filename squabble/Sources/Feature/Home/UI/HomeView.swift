import SwiftUI

struct HomeView: View {
    @State private var isShowingAccount = false

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Nothing to squabble about yet.",
                systemImage: "receipt",
                description: Text("Add a bill and we'll find something.")
            )
            .navigationTitle("Squabble")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Account", systemImage: "person.crop.circle") {
                        isShowingAccount = true
                    }
                }
            }
            .sheet(isPresented: $isShowingAccount) {
                AccountView()
            }
        }
    }
}
