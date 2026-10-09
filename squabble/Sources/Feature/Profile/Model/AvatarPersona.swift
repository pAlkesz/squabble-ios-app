import Foundation

/// A joke character to wear as an avatar — picking one means taking on its slogan.
/// The art ships in the app, so a persona avatar costs no upload and no download.
/// Raw values are stored in Firestore: rename a case freely, never its raw value.
/// Names describe the persona, not whoever inspired it: the repo is public.
nonisolated enum AvatarPersona: String, CaseIterable, Sendable {
    case bigSpender
    case afterPayday
    case methodActor
    case worthWhatYouHave
    case artExpert
    case tooMuchForYou
    case chunkBiter
    case companyFunded
    case debtSpiral
    case tricklingIn

    var slogan: String {
        switch self {
        case .bigSpender:
            String(localized: "Money is no object", comment: "Avatar persona slogan: the big spender.")
        case .afterPayday:
            String(localized: "I'll pay you back after payday", comment: "Avatar persona slogan: always broke until the next salary. Hungarian original: 'Majd ötödike után megadom'.")
        case .methodActor:
            String(localized: "Jesus was an actor", comment: "Avatar persona slogan: a quotable actor. Hungarian original: 'Jézus színész volt'.")
        case .worthWhatYouHave:
            String(localized: "If you've got nothing, that's what you're worth", comment: "Avatar persona slogan: a well-known Hungarian political quote, 'Akinek nincs semmije, az annyit is ér'.")
        case .artExpert:
            String(localized: "I know everything about art", comment: "Avatar persona slogan: the self-declared connoisseur. Hungarian original: 'Mindent tudok a művészetről'.")
        case .tooMuchForYou:
            String(localized: "If I'm too much for you, you're not enough for me", comment: "Avatar persona slogan: unapologetically a lot. Hungarian original: 'Akinek én sok vagyok, az nekem kevés'.")
        case .chunkBiter:
            String(localized: "I'll bite a chunk out of your ass", comment: "Avatar persona slogan: a rapper's threat. Hungarian original: 'Kiharapok egy darabot a seggedből'.")
        case .companyFunded:
            String(localized: "I didn't get state funding, my company did", comment: "Avatar persona slogan: a famous non-denial. Hungarian original: 'Én nem kaptam állami támogatást, a cégem kapott'.")
        case .debtSpiral:
            String(localized: "We cannot go into never-ending spirals of debt", comment: "Avatar persona slogan: a European political quote, originally in English.")
        case .tricklingIn:
            String(localized: "A little trickles in here and there", comment: "Avatar persona slogan: money keeps dripping in. Hungarian original: 'Egy kicsit csurran-cseppen'.")
        }
    }
}
