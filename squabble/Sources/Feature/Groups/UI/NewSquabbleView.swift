import FactoryKit
import SwiftUI

/// The `+` sheet on home: name the squabble, pick its currency, add people by handle.
/// Creating it writes to the local cache, so it works offline; only looking people up
/// needs the internet.
struct NewSquabbleView: View {
    let onCreate: (String) -> Void

    @Injected(\.profileRepository) private var profiles
    @Environment(GroupsStore.self) private var groups
    @Environment(\.dismiss) private var dismiss
    @State private var draft: NewSquabbleDraft
    @State private var handleQuery = ""
    @State private var lookup: MemberLookup = .idle
    @State private var isPickingCurrency = false
    @State private var failure: String?
    @FocusState private var focusedField: FocusedField?

    private enum FocusedField {
        case name
        case handle
    }

    init(creator: UserProfile, currencyCode: String, onCreate: @escaping (String) -> Void) {
        self.onCreate = onCreate
        _draft = State(initialValue: NewSquabbleDraft(creator: creator, currencyCode: currencyCode))
    }

    var body: some View {
        List {
            Section {
                TextField(
                    "Name",
                    text: Binding(get: { draft.name }, set: { draft.setName($0) }),
                    prompt: Text("Lake trip, flat 4B, Tuesday's pizza…", comment: "New squabble: placeholder in the name field.")
                )
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit { focusedField = .handle }
                .listRowBackground(Color.white.opacity(0.08))
            } header: {
                Text("Name", comment: "New squabble: header above the name field.")
            }

            Section {
                currencyRow
            } header: {
                Text("Currency", comment: "New squabble: header above the currency row.")
            } footer: {
                Text("Everyone's balance shows up in this currency.", comment: "New squabble: footer under the currency row.")
            }

            Section {
                memberRow(draft.creator, isCreator: true)
                ForEach(draft.members, id: \.id) { member in
                    memberRow(member, isCreator: false)
                }
                handleField
            } header: {
                Text("Members · \(draft.memberCount)", comment: "New squabble: header above the members, with how many there are.")
            } footer: {
                FieldMessageFooter(message: lookupMessage)
            }
        }
        .scrollContentBackground(.hidden)
        .tint(Color.accent)
        .navigationTitle(Text("New squabble"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isPickingCurrency) {
            SquabbleCurrencyPicker(selection: $draft.currencyCode)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create", action: create)
                    .disabled(!draft.canCreate)
            }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: failure ?? "")
        }
        .onAppear { focusedField = .name }
    }

    private var lookupMessage: SquabbleFieldMessage {
        if let problem = lookup.message {
            return SquabbleFieldMessage(text: problem, tone: .problem)
        }
        return SquabbleFieldMessage(
            text: String(localized: "Add people by their exact handle.", comment: "New squabble: footer under the members when nothing went wrong."),
            tone: .hint
        )
    }

    private var currencyRow: some View {
        let option = CurrencyOption(code: draft.currencyCode)
        return Button {
            isPickingCurrency = true
        } label: {
            HStack(spacing: 14) {
                CurrencyFlag(option: option, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: option.name)
                        .font(.body.weight(.semibold))
                    Text(verbatim: CurrencyRow.detail(for: option))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.white.opacity(0.08))
    }

    private func memberRow(_ profile: UserProfile, isCreator: Bool) -> some View {
        HStack(spacing: 12) {
            AvatarView(profile.avatar, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: profile.displayName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(verbatim: profile.handle.description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
            if isCreator {
                Text("You", comment: "New squabble: tag on the creator's own row.")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.14), in: .capsule)
            } else {
                Button {
                    withAnimation { draft.remove(profile.id) }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Remove \(profile.displayName)", comment: "New squabble: remove a member. The argument is their name."))
            }
        }
        .listRowBackground(Color.white.opacity(0.08))
    }

    private var handleField: some View {
        HStack(spacing: 12) {
            TextField(
                "Handle",
                text: $handleQuery,
                prompt: Text(verbatim: "@handle")
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: .handle)
            .submitLabel(.search)
            .onSubmit { Task { await addByHandle() } }
            .onChange(of: handleQuery) {
                if lookup != .searching { lookup = .idle }
            }
            if lookup == .searching {
                ProgressView()
            } else {
                Button("Add") {
                    Task { await addByHandle() }
                }
                .font(.body.weight(.semibold))
                .disabled(handleQuery.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .listRowBackground(Color.white.opacity(0.08))
    }

    private func addByHandle() async {
        guard lookup != .searching else { return }
        let handle: Handle
        do {
            handle = try Handle(validating: handleQuery)
        } catch {
            lookup = .invalid(error)
            return
        }
        // Settled without the server where we can.
        if handle == draft.creator.handle {
            lookup = .isYou
            return
        }
        if let member = draft.members.first(where: { $0.handle == handle }) {
            lookup = .alreadyAdded(member.displayName)
            return
        }
        lookup = .searching
        let result: MemberLookup
        do {
            if let profile = try await profiles.profile(forHandle: handle) {
                result = add(profile)
            } else {
                result = .notFound(handle)
            }
        } catch ProfileError.offline {
            result = .offline
        } catch {
            AppLog.error(error, "Handle lookup failed")
            result = .failed
        }
        lookup = result
    }

    private func add(_ profile: UserProfile) -> MemberLookup {
        let outcome = withAnimation { draft.add(profile) }
        switch outcome {
        case .added:
            handleQuery = ""
            return .idle
        case .isCreator: return .isYou
        case .alreadyAdded: return .alreadyAdded(profile.displayName)
        case .full: return .full
        }
    }

    private func create() {
        do {
            let id = try groups.create(draft)
            dismiss()
            onCreate(id)
        } catch {
            failure = error.localizedDescription
        }
    }
}
