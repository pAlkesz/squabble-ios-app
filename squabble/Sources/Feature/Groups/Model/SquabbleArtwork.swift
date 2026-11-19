import Foundation

/// The drawings a squabble can have instead of a photo, each a playful take on the
/// `person.3` symbol. Raw values are stored: never rename one. An app that doesn't know an
/// id shows the first drawing, so new ones ship without a rules deploy.
nonisolated enum SquabbleArtwork: String, CaseIterable, Sendable {
    case trio
    case suits
}
