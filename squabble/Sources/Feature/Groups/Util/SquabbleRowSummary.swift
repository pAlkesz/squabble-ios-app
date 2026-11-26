import Foundation

/// The line under a squabble's name in the lists: the latest thing that happened, or, before
/// anything has, what to do first.
enum SquabbleRowSummary {
    static func text(for group: SquabbleGroup, me: String?) -> String {
        guard let activity = group.lastActivity else {
            return group.currentMembers.count > 1
                ? String(localized: "No messages yet. Say hello!", comment: "Squabble row: nothing has happened yet in a squabble with other people in it.")
                : String(localized: "Invite people to the squabble", comment: "Squabble row: the user is still alone in the squabble.")
        }
        // One line in the row, so a message's line breaks become spaces.
        let title = (activity.text ?? "").split(whereSeparator: \.isNewline).joined(separator: " ")
        if activity.by == me {
            return switch activity.kind {
            case .message:
                String(localized: "You: \(title)", comment: "Squabble row: the user's own latest message.")
            case .messageDeleted:
                String(localized: "You deleted a message", comment: "Squabble row: the latest message was the user's, and they deleted it.")
            case .billAdded:
                String(localized: "You added “\(title)”", comment: "Squabble row: the user added a bill; the bill's title follows.")
            case .billEdited:
                String(localized: "You edited “\(title)”", comment: "Squabble row: the user edited a bill.")
            case .billDeleted:
                String(localized: "You deleted “\(title)”", comment: "Chat: line in place of a bill the user deleted; its title.")
            }
        }
        let name = BillText.name(of: activity.by, in: group)
        return switch activity.kind {
        case .message:
            String(localized: "\(name): \(title)", comment: "Squabble row: someone's latest message; their name, then the message.")
        case .messageDeleted:
            String(localized: "\(name) deleted a message", comment: "Squabble row: the latest message was deleted by its author.")
        case .billAdded:
            String(localized: "\(name) added “\(title)”", comment: "Squabble row: someone added a bill; their name, then the bill's title.")
        case .billEdited:
            String(localized: "\(name) edited “\(title)”", comment: "Squabble row: someone edited a bill.")
        case .billDeleted:
            String(localized: "\(name) deleted “\(title)”", comment: "Chat: line in place of a deleted bill; who deleted it, then its title.")
        }
    }
}
