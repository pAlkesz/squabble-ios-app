import SwiftUI

extension AvatarPersona {
    var image: ImageResource {
        switch self {
        case .bigSpender: .personaBigSpender
        case .afterPayday: .personaAfterPayday
        case .methodActor: .personaMethodActor
        case .worthWhatYouHave: .personaWorthWhatYouHave
        case .artExpert: .personaArtExpert
        case .tooMuchForYou: .personaTooMuchForYou
        case .chunkBiter: .personaChunkBiter
        case .companyFunded: .personaCompanyFunded
        case .debtSpiral: .personaDebtSpiral
        case .tricklingIn: .personaTricklingIn
        }
    }
}
