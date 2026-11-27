import Foundation

/// Why a message was reported, picked in `ChatReportSheet`. Raw values are stored in
/// `reports/` and checked by the rules: never rename one.
nonisolated enum ChatReportReason: String, CaseIterable, Identifiable, Sendable {
    case harassment
    case hate
    case scam
    case spam
    case sexual
    case violence
    case other

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .harassment: LocalizedStringResource("Harassment or bullying", comment: "Report sheet: reason for reporting a message.")
        case .hate: LocalizedStringResource("Hate speech", comment: "Report sheet: reason for reporting a message.")
        case .scam: LocalizedStringResource("Scam or fraud", comment: "Report sheet: reason for reporting a message.")
        case .spam: LocalizedStringResource("Spam", comment: "Report sheet: reason for reporting a message.")
        case .sexual: LocalizedStringResource("Sexual content", comment: "Report sheet: reason for reporting a message.")
        case .violence: LocalizedStringResource("Violence or threats", comment: "Report sheet: reason for reporting a message.")
        case .other: LocalizedStringResource("Something else", comment: "Report sheet: reason for reporting a message that fits none of the others.")
        }
    }

    var systemImage: String {
        switch self {
        case .harassment: "person.fill.xmark"
        case .hate: "hand.raised.fill"
        case .scam: "exclamationmark.shield.fill"
        case .spam: "envelope.badge.fill"
        case .sexual: "eye.slash.fill"
        case .violence: "bolt.fill"
        case .other: "ellipsis.circle.fill"
        }
    }
}
