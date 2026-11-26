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
    @State private var isNearTop = false
    @State private var isSettled = true
    @State private var draft = ""
    @State private var replyingTo: ChatMessage?
    @State private var deleting: ChatMessage?
    @State private var reporting: ChatMessage?
    @State private var billForm: BillDraft?
    @State private var openBill: OpenBill?
    @State private var reactionsOf: OpenMessage?
    @State private var menu: MessageMenu?
    /// Hidden in the list while the menu shows its copy, so only one is ever visible.
    @State private var liftedMessageID: String?
    /// Opened once the details sheet is gone; two sheets can't swap in one go.
    @State private var billToEdit: BillDraft?
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
        .task(id: isAwaitingServer) { await chat.observe(isAwaitingServer: isAwaitingServer) }
    }

    private var isAwaitingServer: Bool {
        groups.group(id: groupID)?.isAwaitingServer ?? false
    }

    private func content(_ group: SquabbleGroup) -> some View {
        ScrollViewReader { proxy in
            // Mounted with its content, so it opens at the bottom rather than scrolling there.
            if !chat.hasLoaded {
                Color.clear
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(ChatTimeline.rows(for: chat.entries)) { row in
                            switch row {
                            case .day(let day):
                                ChatDayHeader(day: day)
                            case .message(let message, let startsRun, let endsRun, let showsName):
                                messageRow(message, startsRun: startsRun, endsRun: endsRun, showsName: showsName, in: group, proxy: proxy)
                                    .id(message.id)
                            case .bill(let bill, let startsRun, let endsRun):
                                BillCard(bill: bill, group: group, myUID: session.user?.id, startsRun: startsRun, endsRun: endsRun) {
                                    isComposing = false
                                    openBill = OpenBill(id: bill.id)
                                }
                                .id(bill.id)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
                .defaultScrollAnchor(.bottom)
                // An older page is added above, which would leave the list at the very top of it:
                // stay on what was first. Loading waits for the scroll to settle, because its
                // momentum would override this.
                .onChange(of: chat.olderPageAnchor) { _, anchor in
                    guard let anchor else { return }
                    proxy.scrollTo(anchor, anchor: .top)
                }
                .onScrollPhaseChange { _, phase in
                    isSettled = phase == .idle
                }
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top < Self.olderPageDistance
                } action: { _, isNearTop in
                    self.isNearTop = isNearTop
                }
                // Also once the connection comes back.
                .task(id: OlderPageTrigger(isAtTop: isNearTop && isSettled, isLive: chat.isLive)) {
                    if isNearTop, isSettled { await chat.loadOlder() }
                }
                .overlay(alignment: .top) {
                    if chat.isLoadingOlder {
                        ProgressView().tint(.white).padding(.top, 8)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                // iOS 26's soft fade under the bar; iOS 27 no longer defaults to it.
                .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
                .overlay {
                    if chat.entries.isEmpty {
                        emptyState(group)
                    }
                }
                .onChange(of: ChatEnd(id: chat.entries.last?.id, isLive: chat.isLive)) { old, new in
                    guard let id = new.id, id != old.id else { return }
                    // Catching up from the cache to the server isn't news, so it doesn't move.
                    let isNews = old.isLive || chat.entries.last?.isPending == true
                    withAnimation(isNews ? .snappy : nil) { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
        }
        // Tapping anywhere above the composer puts the keyboard away. Simultaneous, so bubbles
        // and bill cards still get their own taps. Deferred out of the tap's update: changed
        // inside it, the layout snapped down instead of following the keyboard.
        .simultaneousGesture(TapGesture().onEnded { Task { isComposing = false } })
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
                    onSend: send,
                    onAddBill: {
                        guard let uid = session.user?.id else { return }
                        isComposing = false
                        billForm = BillDraft(newBillIn: group, by: uid)
                    }
                )
                .frame(maxWidth: 720)
            }
        }
        .sheet(item: $billForm) { draft in
            if let uid = session.user?.id {
                BillFormView(draft: draft, group: group, uid: uid) { bill, isNew in
                    chat.save(bill, isNew: isNew)
                }
                .presentationBackground(Color.backdropDeep)
            }
        }
        .sheet(item: $openBill, onDismiss: {
            billForm = billToEdit
            billToEdit = nil
        }) { open in
            // By id, so an edit by someone else shows while it's open.
            if let uid = session.user?.id, let bill = chat.bill(id: open.id), !bill.isDeleted {
                BillDetailView(
                    bill: bill,
                    group: group,
                    uid: uid,
                    onEdit: { billToEdit = BillDraft(editing: bill, in: group) },
                    onDelete: { chat.delete(bill, by: uid) }
                )
                .presentationBackground { ProfileBackdrop() }
            }
        }
        .fullScreenCover(item: $menu) { open in
            messageMenu(open, in: group)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: menu?.id) { _, new in new != nil }
        .sheet(item: $reactionsOf) { open in
            // By id, so a reaction coming or going shows while it's open.
            if let message = chat.message(id: open.id) {
                ChatReactionsSheet(message: message, group: group, myUID: session.user?.id) {
                    guard let uid = session.user?.id, let emoji = message.reactions[uid] else { return }
                    chat.toggleReaction(emoji, on: message, by: uid)
                }
            }
        }
        .confirmationDialog(
            Text("Delete this message?", comment: "Chat: title of the delete confirmation."),
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible,
            presenting: deleting
        ) { message in
            Button(role: .destructive) {
                chat.delete(message, lastActivity: group.lastActivity)
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
    }

    @ToolbarContentBuilder
    private func toolbar(_ group: SquabbleGroup) -> some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 0) {
                Text(verbatim: group.name)
                    .font(.headline)
                    .lineLimit(1)
                standing(group)
                    .font(.subheadline)
                    .lineLimit(1)
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

    private func messageRow(
        _ message: ChatMessage,
        startsRun: Bool,
        endsRun: Bool,
        showsName: Bool,
        in group: SquabbleGroup,
        proxy: ScrollViewProxy
    ) -> some View {
        let uid = session.user?.id
        return ChatMessageRow(
            message: message,
            author: group.members[message.authorID],
            replyAuthorName: message.replyTo.map { ChatMessageRow.name(of: group.members[$0.authorID]) },
            isMine: message.authorID == uid,
            startsRun: startsRun,
            endsRun: endsRun,
            showsName: showsName,
            isLifted: liftedMessageID == message.id,
            myUID: uid,
            onOpenMenu: { frame in
                isComposing = false
                // Without the cover's slide: the menu fades in over the message itself.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    menu = MessageMenu(id: message.id, anchor: frame, showsName: showsName, endsRun: endsRun)
                }
            },
            onShowReactions: { reactionsOf = OpenMessage(id: message.id) },
            onShowQuoted: { id in
                guard chat.message(id: id) != nil else { return }
                withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
            }
        )
    }

    private func standing(_ group: SquabbleGroup) -> Text {
        guard group.balances != nil, let uid = session.user?.id else {
            return Text("No bills yet", comment: "Squabble page: subtitle under the name in the bar while there are no bills.")
        }
        let balance = group.balance(of: uid)
        guard balance.minorUnits != 0 || group.isInvolved(uid) else {
            return Text("You're not in any bills", comment: "Squabble page: subtitle in the bar when there are bills but the user neither paid nor shares any.")
        }
        return Text(verbatim: BillText.standing(balance))
    }

    private struct OpenBill: Identifiable {
        let id: String
    }

    private struct OpenMessage: Identifiable {
        let id: String
    }

    private struct MessageMenu: Identifiable {
        let id: String
        let anchor: CGRect
        /// As the row shows it, so the menu's copy is the same bubble.
        let showsName: Bool
        let endsRun: Bool
    }

    private func closeMenu(then next: @escaping () -> Void = {}) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            menu = nil
            liftedMessageID = nil
        }
        next()
    }

    @ViewBuilder
    private func messageMenu(_ open: MessageMenu, in group: SquabbleGroup) -> some View {
        let uid = session.user?.id
        if let message = chat.message(id: open.id), !message.isDeleted {
            let isMine = message.authorID == uid
            ChatMessageMenu(
                message: message,
                bubble: ChatBubble(
                    message: message,
                    authorName: !isMine && open.showsName ? ChatMessageRow.name(of: group.members[message.authorID]) : nil,
                    replyAuthorName: message.replyTo.map { ChatMessageRow.name(of: group.members[$0.authorID]) },
                    isMine: isMine,
                    hasTail: open.endsRun
                ),
                anchor: open.anchor,
                isMine: isMine,
                myReaction: uid.flatMap { message.reactions[$0] },
                onReact: { emoji in
                    if let uid { chat.toggleReaction(emoji, on: message, by: uid) }
                    closeMenu()
                },
                onReply: {
                    closeMenu {
                        replyingTo = message
                        isComposing = true
                    }
                },
                onDelete: { closeMenu { deleting = message } },
                onReport: { closeMenu { reporting = message } },
                onShown: { liftedMessageID = message.id },
                onClose: { closeMenu() }
            )
            .presentationBackground(.clear)
        }
    }

    private struct ChatEnd: Equatable {
        let id: String?
        let isLive: Bool
    }

    private struct OlderPageTrigger: Equatable {
        let isAtTop: Bool
        let isLive: Bool
    }

    private static let olderPageDistance: CGFloat = 100

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
            // Not a scroll view sized to the screen: that one snapped to the keyboard instead of
            // riding up with it. Scrolls only when it can't fit, as with large text.
            ViewThatFits(in: .vertical) {
                readyCentred(group)
                ScrollView { readyCentred(group) }
            }
        }
    }

    private func readyCentred(_ group: SquabbleGroup) -> some View {
        ready(group)
            .padding(16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The symbols differ in width; a shared column lines the texts up.
    private static let readyIconWidth: CGFloat = 28

    private func ready(_ group: SquabbleGroup) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 30))
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text("Your squabble is ready", comment: "Squabble page: title while there are no bills yet.")
                    .font(.headline)
                if !group.isArchived {
                    SquabbleInviteLink(group: group)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text("Add bills, then settle up", comment: "Squabble page: first point in the 'ready' card.")
                } icon: {
                    Image(systemName: "checkmark")
                        .frame(width: Self.readyIconWidth)
                }
                Label {
                    Text("Bring people in. They'll need the app too, no freeloaders.", comment: "Squabble page: second point in the 'ready' card. Members must have an account.")
                } icon: {
                    Image(systemName: "person.2.fill")
                        .frame(width: Self.readyIconWidth)
                }
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.white.opacity(0.08), in: .rect(cornerRadius: SquabbleMetrics.cornerRadius))
        }
    }
}
