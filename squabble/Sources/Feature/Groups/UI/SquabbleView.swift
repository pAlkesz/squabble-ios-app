import SwiftUI

/// A squabble, laid out like Revolut's group page: the name and the user's standing in the
/// bar with the picture beside it (which opens the info page), the chat in the middle, and
/// the composer with Add a bill at the bottom (docs/specs/chat.md). Before anyone says
/// anything the middle is a "ready" state.
struct SquabbleView: View {
    let groupID: String

    @Environment(GroupsStore.self) private var groups
    @Environment(AuthSession.self) private var session
    @State private var chat: ChatStore
    @State private var draft = ""
    @State private var replyingTo: ChatMessage?
    @State private var deleting: ChatMessage?
    @State private var reporting: ChatMessage?
    @State private var isInviting = false
    @FocusState private var isComposing: Bool
    #if DEBUG
    @Environment(DebugBalances.self) private var debugBalances: DebugBalances?
    #endif

    init(groupID: String) {
        self.groupID = groupID
        _chat = State(initialValue: ChatStore(groupID: groupID))
    }

    var body: some View {
        Group {
            if let group = groups.group(id: groupID) {
                content(group)
            } else if groups.hasLoaded {
                SquabbleUnavailableView()
            }
        }
        .foregroundStyle(.white)
        .navigationBarTitleDisplayMode(.inline)
        .background { SquabbleMoodBackdrop(groupID: groupID) }
        .task { await chat.observe() }
    }

    private func content(_ group: SquabbleGroup) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    if chat.canLoadOlder, !chat.messages.isEmpty {
                        ProgressView()
                            .tint(.white)
                            .padding(.vertical, 12)
                            .task { await chat.loadOlder() }
                    }
                    ForEach(ChatTimeline.rows(for: chat.messages)) { row in
                        switch row {
                        case .day(let day):
                            ChatDayHeader(day: day)
                        case .message(let message, let startsRun, let endsRun):
                            messageRow(message, startsRun: startsRun, endsRun: endsRun, in: group, proxy: proxy)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            // iOS 26's soft fade under the bar; iOS 27 no longer defaults to it.
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .overlay {
                if chat.hasLoaded, chat.messages.isEmpty {
                    emptyState(group)
                }
            }
            .onChange(of: chat.messages.last?.id) { _, id in
                guard let id else { return }
                withAnimation(.snappy) { proxy.scrollTo(id, anchor: .bottom) }
            }
        }
        .navigationTitle(Text(verbatim: group.name))
        .toolbar { toolbar(group) }
        #if DEBUG
        .safeAreaBar(edge: .top) {
            DebugBalanceSlider(groupID: group.id, currencyCode: group.currencyCode)
        }
        #endif
        .safeAreaBar(edge: .bottom) {
            if !group.isArchived {
                ChatComposer(
                    text: $draft,
                    replyingTo: replyingTo,
                    replyAuthorName: replyingTo.map { ChatMessageRow.name(of: group.members[$0.authorID]) },
                    isFocused: $isComposing,
                    onCancelReply: { replyingTo = nil },
                    onSend: send
                )
                .frame(maxWidth: 720)
            }
        }
        .confirmationDialog(
            Text("Delete this message?", comment: "Chat: title of the delete confirmation."),
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible,
            presenting: deleting
        ) { message in
            Button(role: .destructive) {
                chat.delete(message)
            } label: {
                Text("Delete for everyone", comment: "Chat: confirms deleting a message.")
            }
        } message: { _ in
            Text("Everyone will see that a message was deleted, just not what it said.", comment: "Chat: explanation in the delete confirmation.")
        }
        .confirmationDialog(
            Text("Report this message?", comment: "Chat: title of the report confirmation."),
            isPresented: Binding(get: { reporting != nil }, set: { if !$0 { reporting = nil } }),
            titleVisibility: .visible,
            presenting: reporting
        ) { message in
            Button(role: .destructive) {
                if let uid = session.user?.id { chat.report(message, by: uid) }
            } label: {
                Text("Report", comment: "Chat: long-press action that reports someone else's message.")
            }
        } message: { _ in
            Text("We'll take a look. The author won't know it was you.", comment: "Chat: explanation in the report confirmation.")
        }
        .sheet(isPresented: $isInviting) {
            SquabbleInviteSheet(groupID: group.id)
                .presentationBackground { ProfileBackdrop() }
        }
    }

    @ToolbarContentBuilder
    private func toolbar(_ group: SquabbleGroup) -> some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 0) {
                Text(verbatim: group.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("No bills yet", comment: "Squabble page: subtitle under the name in the bar while there are no bills.")
                    .font(.subheadline)
            }
            .foregroundStyle(.white)
            #if DEBUG
            .contentShape(.rect)
            .onLongPressGesture { debugBalances?.toggle(group.id) }
            #endif
        }
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(value: HomeRoute.squabbleInfo(id: group.id)) {
                SquabbleImageView(group.image, size: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Squabble info", comment: "Squabble page: VoiceOver label for the picture in the bar, which opens the squabble's info page."))
        }
        .sharedBackgroundVisibility(.hidden)
    }

    private func messageRow(_ message: ChatMessage, startsRun: Bool, endsRun: Bool, in group: SquabbleGroup, proxy: ScrollViewProxy) -> some View {
        let uid = session.user?.id
        return ChatMessageRow(
            message: message,
            author: group.members[message.authorID],
            replyAuthorName: message.replyTo.map { ChatMessageRow.name(of: group.members[$0.authorID]) },
            isMine: message.authorID == uid,
            startsRun: startsRun,
            endsRun: endsRun,
            myUID: uid,
            onReact: { emoji in
                if let uid { chat.toggleReaction(emoji, on: message, by: uid) }
            },
            onReply: {
                replyingTo = message
                isComposing = true
            },
            onDelete: { deleting = message },
            onReport: { reporting = message },
            onShowQuoted: { id in
                guard chat.message(id: id) != nil else { return }
                withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
            }
        )
    }

    private func send() {
        guard let uid = session.user?.id else { return }
        chat.send(draft, replyingTo: replyingTo, as: uid)
        draft = ""
        replyingTo = nil
    }

    @ViewBuilder
    private func emptyState(_ group: SquabbleGroup) -> some View {
        if chat.failed {
            Text(verbatim: ChatError.unavailable.localizedDescription)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(32)
        } else {
            ScrollView {
                ready(group)
                    .padding(16)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.vertical) { height, _ in height }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func ready(_ group: SquabbleGroup) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 30))
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text("Your squabble is ready", comment: "Squabble page: title while there are no bills yet.")
                    .font(.headline)
                Text(memberLine(group))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text("Add bills, then settle up", comment: "Squabble page: first point in the 'ready' card.")
                } icon: {
                    Image(systemName: "checkmark")
                }
                Label {
                    Text("Bring people in. They'll need the app too, no freeloaders.", comment: "Squabble page: second point in the 'ready' card. Members must have an account.")
                } icon: {
                    Image(systemName: "person.2.fill")
                }
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.white.opacity(0.08), in: .rect(cornerRadius: SquabbleMetrics.cornerRadius))
            if !group.isArchived {
                Button {
                    isInviting = true
                } label: {
                    Label {
                        Text("Invite people", comment: "Squabble info: button that opens the invite link and QR code.")
                    } icon: {
                        Image(systemName: "qrcode")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.backdropDeep)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.white, in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func memberLine(_ group: SquabbleGroup) -> String {
        let count = group.currentMembers.count
        if count <= 1 {
            return String(localized: "Just you so far. Squabbling alone is called thinking.", comment: "Squabble page: under the 'ready' title when the user is the only member.")
        }
        return String(localized: "\(count) members, zero bills. For now.", comment: "Squabble page: under the 'ready' title when there are other members.")
    }
}
