import SwiftUI

extension View {
    /// Sizes a sheet to its content and gives it the app's opaque backdrop. Opaque, as on
    /// the ThermalGlass sheets: glass buttons on the default glass sheet lose their glass
    /// look and read as flat capsules. Apply to the sheet's root view.
    func fittedSheet() -> some View {
        modifier(FittedSheet())
    }
}

private struct FittedSheet: ViewModifier {
    /// Measured content height; a guess until the first layout.
    @State private var height: CGFloat = 360

    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { height = $0 }
            .presentationDetents([.height(height)])
            .presentationBackground(Color.backdropDeep)
    }
}
