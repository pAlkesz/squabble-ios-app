import SwiftUI

/// The first few members' avatars, overlapping, with a "+N" disc for the rest.
struct MemberAvatarStack: View {
    let members: [GroupMember]
    var size: CGFloat = 36
    var limit = 3

    var body: some View {
        HStack(spacing: -size * 0.3) {
            ForEach(members.prefix(limit)) { member in
                AvatarView(member.avatar, size: size)
                    .overlay { Circle().strokeBorder(Color.backdropDeep, lineWidth: 2) }
            }
            if members.count > limit {
                Text(verbatim: "+\(members.count - limit)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(Color.backdropMid, in: .circle)
                    .overlay { Circle().strokeBorder(Color.backdropDeep, lineWidth: 2) }
            }
        }
        .accessibilityHidden(true)
    }
}
