import SwiftUI
import UIKit

/// Presents SwiftUI content with UIKit's zoom transition out of the leading toolbar button
/// of the visible navigation stack, over a blurred screen — Revolut's profile zoom. SwiftUI's
/// `.navigationTransition(.zoom)` can't do this: it has no blur behind the zoom, and a blur
/// of our own drops out mid-transition. Mark the button's content with `zoomSource(for:)`.
@MainActor
final class ZoomPresenter {
    private enum Failure: Error {
        case toolbarButtonNotFound
    }

    private static let blur = UIBlurEffect(style: .dark)

    /// Where the source should land in the presented content, in screen coordinates —
    /// e.g. a small avatar onto the big one.
    var alignmentRect: CGRect?

    fileprivate weak var anchorView: UIView?
    private weak var presented: UIViewController?

    func present(_ content: some View) {
        guard let presenter = Self.topViewController() else { return }

        // The transition's own blur leaves with the transition, so the screen keeps a matching
        // one behind its content. It blurs whatever is under it on screen even while the zoom
        // scales it, so the hand-off is invisible.
        let host = UIHostingController(rootView: content.background {
            BlurView(effect: Self.blur).ignoresSafeArea()
        })
        host.view.backgroundColor = .clear
        // Keeps the presenting screen in the window, so it shows through, blurred, once open.
        host.modalPresentationStyle = .overFullScreen
        host.preferredTransition = transition(from: presenter)

        presented = host
        presenter.present(host, animated: true)
    }

    func dismiss(animated: Bool = true) {
        presented?.dismiss(animated: animated)
    }

    private func transition(from presenter: UIViewController) -> UIViewController.Transition? {
        let options = UIViewController.Transition.ZoomOptions()
        options.dimmingVisualEffect = Self.blur
        options.alignmentRectProvider = { [weak self] _ in self?.alignmentRect }

        // Zooming from the bar button itself keeps its Liquid Glass morph. SwiftUI keeps its
        // toolbar items in item groups on the bar's top item; that's unpublished, so if an
        // iOS update moves them, zoom from the anchor view behind the button instead.
        if let item = Self.leadingToolbarButton(under: presenter) {
            return .zoom(options: options) { _ in item }
        }
        AppLog.error(Failure.toolbarButtonNotFound, "Zoom fell back to the source anchor view")
        guard anchorView != nil else { return nil }
        return .zoom(options: options) { [weak self] _ in self?.anchorView }
    }

    private static func leadingToolbarButton(under controller: UIViewController) -> UIBarButtonItem? {
        navigationController(in: controller)?.navigationBar.topItem?
            .leadingItemGroups.first?.barButtonItems.first
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let next = top?.presentedViewController { top = next }
        return top
    }

    private static func navigationController(in controller: UIViewController) -> UINavigationController? {
        if let navigation = controller as? UINavigationController { return navigation }
        for child in controller.children {
            if let found = navigationController(in: child) { return found }
        }
        return nil
    }
}

extension View {
    /// Marks the view a `ZoomPresenter` zooms out of when it can't find the toolbar button.
    func zoomSource(for presenter: ZoomPresenter) -> some View {
        background { ZoomAnchor(presenter: presenter) }
    }
}

private struct ZoomAnchor: UIViewRepresentable {
    let presenter: ZoomPresenter

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        presenter.anchorView = view
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        presenter.anchorView = view
    }
}

private struct BlurView: UIViewRepresentable {
    let effect: UIVisualEffect

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: effect)
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {}
}
