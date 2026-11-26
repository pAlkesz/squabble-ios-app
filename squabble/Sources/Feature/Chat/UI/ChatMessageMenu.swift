import SwiftUI
import UIKit

/// The long-press menu over a message, laid out like Messenger's: the page blurred, a large
/// reaction bar of glass above the message (its + opens `EmojiPickerSheet` for any emoji), the
/// message where it was, and its actions on glass below. The bar and the actions grow out of
/// the message as they fade in, and shrink back into it before anything they lead to happens.
/// The three move as a block only as far as it takes to fit on screen. Tapping outside closes it.
struct ChatMessageMenu: View {
    let message: ChatMessage
    let bubble: ChatBubble
    /// The bubble's frame on screen when the menu opened.
    let anchor: CGRect
    let isMine: Bool
    let myReaction: String?
    /// Each runs once the menu has animated away.
    let onReact: (String) -> Void
    let onReply: () -> Void
    let onDelete: () -> Void
    let onReport: () -> Void
    let onClose: () -> Void

    @State private var contentSize: CGSize = .zero
    @State private var barHeight: CGFloat = 0
    @State private var isShown = false
    @State private var isPickingEmoji = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let spacing: CGFloat = 10
    private static let margin: CGFloat = 12

    var body: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            let frame = anchor.offsetBy(dx: -origin.x, dy: -origin.y)
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(0.3))
                    .ignoresSafeArea()
                    .opacity(isShown ? 1 : 0)
                    .onTapGesture { close(then: onClose) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(Text("Close", comment: "Chat menu: VoiceOver label for the blurred background, which closes the menu."))
                content(bubbleWidth: frame.width, maxBubbleHeight: proxy.size.height * 0.45)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { contentSize = $0 }
                    .offset(position(for: frame, in: proxy.size))
                    .opacity(contentSize == .zero ? 0 : 1)
            }
        }
        .sheet(isPresented: $isPickingEmoji) {
            EmojiPickerSheet(selected: myReaction) { emoji in
                isPickingEmoji = false
                close { onReact(emoji) }
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.32, bounce: 0.22)) { isShown = true }
        }
    }

    /// Animates the bar and actions back into the message, then hands over.
    private func close(then next: @escaping () -> Void) {
        withAnimation(.easeIn(duration: 0.16)) {
            isShown = false
        } completion: {
            next()
        }
    }

    /// Where the block's top-left goes: the bubble over where it was, the block kept inside the
    /// screen.
    private func position(for frame: CGRect, in size: CGSize) -> CGSize {
        let x = isMine ? frame.maxX - contentSize.width : frame.minX
        let y = frame.minY - barHeight - Self.spacing
        let maxX = size.width - Self.margin - contentSize.width
        let maxY = size.height - Self.margin - contentSize.height
        return CGSize(
            width: min(max(x, Self.margin), max(maxX, Self.margin)),
            height: min(max(y, Self.margin), max(maxY, Self.margin))
        )
    }

    private func content(bubbleWidth: CGFloat, maxBubbleHeight: CGFloat) -> some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: Self.spacing) {
            reactionBar
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { barHeight = $0 }
                .modifier(Emerge(isShown: isShown, anchor: isMine ? .bottomTrailing : .bottomLeading, reduceMotion: reduceMotion))
            bubble
                .frame(width: bubbleWidth, alignment: isMine ? .trailing : .leading)
                .frame(maxHeight: maxBubbleHeight, alignment: .top)
                // A long message is cut off at the bottom; the tail still reaches past the side.
                .mask { Rectangle().padding(.horizontal, -ChatBubbleShape.tailWidth) }
                .allowsHitTesting(false)
            actions
                .modifier(Emerge(isShown: isShown, anchor: isMine ? .topTrailing : .topLeading, reduceMotion: reduceMotion))
        }
        .fixedSize()
    }

    private var reactionBar: some View {
        HStack(spacing: 4) {
            ForEach(ChatMessage.quickReactions, id: \.self) { emoji in
                Button {
                    close { onReact(emoji) }
                } label: {
                    Text(verbatim: emoji)
                        .font(.system(size: 30))
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(emoji == myReaction ? 0.25 : 0), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(emoji == myReaction ? .isSelected : [])
            }
            Button {
                isPickingEmoji = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.15), in: .circle)
                    .padding(2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("More emoji", comment: "Chat menu: VoiceOver label for the + at the end of the reaction bar, which opens every emoji."))
        }
        .padding(6)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private var actions: some View {
        VStack(spacing: 0) {
            action(Text("Reply", comment: "Chat: long-press action that replies to a message."), systemImage: "arrowshape.turn.up.left") {
                close(then: onReply)
            }
            Divider().overlay(.white.opacity(0.08))
            action(Text("Copy", comment: "Chat: long-press action that copies a message's text."), systemImage: "doc.on.doc") {
                // SwiftUI has no pasteboard API of its own.
                UIPasteboard.general.string = message.text
                close(then: onClose)
            }
            Divider().overlay(.white.opacity(0.08))
            if isMine {
                action(Text("Delete", comment: "Chat: long-press action that deletes your own message."), systemImage: "trash", isDestructive: true) {
                    close(then: onDelete)
                }
            } else {
                action(Text("Report", comment: "Chat: long-press action that reports someone else's message."), systemImage: "exclamationmark.bubble") {
                    close(then: onReport)
                }
            }
        }
        .frame(width: 240)
        .glassEffect(.regular, in: .rect(cornerRadius: SquabbleMetrics.cornerRadius))
    }

    private func action(_ title: Text, systemImage: String, isDestructive: Bool = false, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack {
                title
                Spacer(minLength: 12)
                Image(systemName: systemImage)
            }
            .font(.body)
            .foregroundStyle(isDestructive ? Color.red : .white)
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// Grows out of the message's edge as it fades in; with Reduce Motion, only fades.
    private struct Emerge: ViewModifier {
        let isShown: Bool
        let anchor: UnitPoint
        let reduceMotion: Bool

        func body(content: Content) -> some View {
            content
                .scaleEffect(isShown || reduceMotion ? 1 : 0.3, anchor: anchor)
                .opacity(isShown ? 1 : 0)
        }
    }
}
