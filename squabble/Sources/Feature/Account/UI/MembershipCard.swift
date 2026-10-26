import SwiftUI

/// The profile as a "Squabble Club" membership card, a printed prop like the welcome receipt
/// and the payment slip: an ID photo, name and handle, a couple of card fields, and the handle
/// as a barcode (a real QR code can take its place once invite links exist). The photo slot
/// is left to the caller, which puts the avatar menu there.
struct MembershipCard<Photo: View>: View {
    let profile: UserProfile
    @ViewBuilder let photo: () -> Photo

    var body: some View {
        VStack(spacing: 0) {
            band
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    photo()
                    details
                }
                barcode
            }
            .padding(16)
        }
        .background(Color.receiptPaper)
        .clipShape(.rect(cornerRadius: 18))
        .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 12)
        .rotationEffect(.degrees(-1.5))
        .frame(maxWidth: 400)
    }

    private var band: some View {
        HStack(spacing: 8) {
            SquabLogoView()
                .frame(width: 26, height: 22)
            Text("SQUABBLE CLUB", comment: "Membership card: the club's name in the green band.")
                .font(.system(.subheadline, design: .monospaced, weight: .heavy))
                .tracking(1.5)
            Spacer(minLength: 0)
            Text("MEMBER", comment: "Membership card: top-right corner of the green band.")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .tracking(1)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.accent)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: profile.displayName)
                    .font(.system(.headline, design: .monospaced, weight: .heavy))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(verbatim: profile.handle.description)
                    .font(.system(.caption, design: .monospaced))
                    .opacity(0.7)
            }
            field(Text("Member since", comment: "Membership card: field label.")) {
                if let memberSince = profile.memberSince {
                    Text(memberSince, format: .dateTime.month(.abbreviated).year())
                } else {
                    Text("Just now", comment: "Membership card: member-since value before the server has dated the profile.")
                }
            }
            field(Text("Valid until", comment: "Membership card: field label.")) {
                Text("Everyone pays up", comment: "Membership card: the joke expiry date.")
            }
        }
        .foregroundStyle(Color.receiptInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func field(_ label: Text, @ViewBuilder value: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            label
                .textCase(.uppercase)
                .font(.system(.caption2, design: .monospaced, weight: .semibold))
                .opacity(0.55)
            value()
                .font(.system(.caption, design: .monospaced, weight: .bold))
        }
    }

    private var barcode: some View {
        VStack(spacing: 4) {
            BarcodeBars(modules: Code128Barcode.modules(for: profile.handle.description) ?? [])
                .frame(height: 34)
            Text(verbatim: profile.handle.description)
                .font(.system(.caption2, design: .monospaced))
                .tracking(3)
                .opacity(0.6)
        }
        .foregroundStyle(Color.receiptInk)
        .accessibilityHidden(true)
    }
}

/// Draws barcode modules as bars filling the available width, in the foreground style.
private struct BarcodeBars: View {
    let modules: [Bool]

    var body: some View {
        Canvas { context, size in
            guard !modules.isEmpty else { return }
            let moduleWidth = size.width / CGFloat(modules.count)
            var bars = Path()
            for (index, isBar) in modules.enumerated() where isBar {
                bars.addRect(CGRect(x: CGFloat(index) * moduleWidth, y: 0, width: moduleWidth, height: size.height))
            }
            context.fill(bars, with: .foreground)
        }
    }
}
