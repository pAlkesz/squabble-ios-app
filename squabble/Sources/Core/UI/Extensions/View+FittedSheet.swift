import SwiftUI

extension View {
    /// Sizes a sheet to its content. By default it also gives it the app's opaque backdrop:
    /// glass buttons on the default glass sheet lose their glass look and read as flat
    /// capsules (as on the ThermalGlass sheets). A sheet without glass buttons can keep the
    /// system's glass with `opaque: false`. Apply to the sheet's root view.
    func fittedSheet(opaque: Bool = true) -> some View {
        modifier(FittedSheet(isOpaque: opaque))
    }
}

private struct FittedSheet: ViewModifier {
    let isOpaque: Bool

    /// Measured content height; a guess until the first layout.
    @State private var height: CGFloat = 360

    func body(content: Content) -> some View {
        let fitted = content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { height = $0 }
            .presentationDetents([.height(height)])
        if isOpaque {
            fitted.presentationBackground(Color.backdropDeep)
        } else {
            fitted
        }
    }
}
