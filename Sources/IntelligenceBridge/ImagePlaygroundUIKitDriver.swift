#if os(iOS)
    import ImagePlayground
    import UIKit

    /// Owns the native controller and reports only public UIKit presentation lifecycle evidence.
    @MainActor
    final class ImagePlaygroundUIKitDriver: NSObject, ImagePlaygroundPresentationDriver,
        ImagePlaygroundViewController.Delegate, UIAdaptivePresentationControllerDelegate
    {
        weak var anchor: ImagePlaygroundPresentationAnchor?
        private var controller: ImagePlaygroundViewController?
        private var requested = false
        private var presenting = false
        private var closing = false
        private var dismissalCompletions: [@MainActor () -> Void] = []
        private var onOpened: @MainActor () -> Void = {}
        private var onResult: @MainActor (URL) -> Void = { _ in }
        private var onCancelled: @MainActor () -> Void = {}

        var isOpen: Bool {
            guard let controller else { return false }
            return controller.presentingViewController != nil && controller.viewIfLoaded?.window != nil
                && !controller.isBeingPresented && !controller.isBeingDismissed
        }

        func present(
            request: ImagePlaygroundBridgeRequest,
            onOpened: @escaping @MainActor () -> Void,
            onResult: @escaping @MainActor (URL) -> Void,
            onCancelled: @escaping @MainActor () -> Void
        ) {
            guard controller == nil else { return }
            let editor = ImagePlaygroundViewController()
            editor.concepts = request.concepts.map { concept in
                switch concept {
                case .extracted(let text, let title): .extracted(from: text, title: title)
                case .text(let text): .text(text)
                }
            }
            editor.delegate = self
            controller = editor
            requested = true
            self.onOpened = onOpened
            self.onResult = onResult
            self.onCancelled = onCancelled
            presentIfReady()
        }

        /// Waits for the owned anchor to attach; the session deadline bounds that wait.
        func presentIfReady() {
            guard requested, !presenting, !closing, let controller, let anchor,
                anchor.viewIfLoaded?.window != nil
            else { return }
            presenting = true
            anchor.present(controller, animated: true) { [weak self, weak controller] in
                guard let self, let controller, self.controller === controller, !self.closing else { return }
                if self.isOpen { self.onOpened() }
            }
            controller.presentationController?.delegate = self
        }

        /// Completes after any in-progress transition and the owned editor's dismissal.
        func dismiss(completion: @escaping @MainActor () -> Void) {
            dismissalCompletions.append(completion)
            guard !closing else { return }
            closing = true
            requested = false
            onOpened = {}
            onResult = { _ in }
            onCancelled = {}
            controller?.delegate = nil
            if let transition = controller?.transitionCoordinator,
                transition.animate(alongsideTransition: nil, completion: { [weak self] _ in self?.dismissController() })
            {
                return
            }
            dismissController()
        }

        func imagePlaygroundViewController(
            _ imagePlaygroundViewController: ImagePlaygroundViewController, didCreateImageAt imageURL: URL
        ) {
            guard controller === imagePlaygroundViewController, !closing else { return }
            onResult(imageURL)
        }

        func imagePlaygroundViewControllerDidCancel(_ imagePlaygroundViewController: ImagePlaygroundViewController) {
            guard controller === imagePlaygroundViewController, !closing else { return }
            onCancelled()
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            guard presentationController.presentedViewController === controller, !closing else { return }
            onCancelled()
        }

        private func dismissController() {
            guard let controller, controller.presentingViewController != nil else {
                finishDismissal()
                return
            }
            controller.dismiss(animated: true) { [weak self] in self?.finishDismissal() }
        }

        private func finishDismissal() {
            controller = nil
            presenting = false
            closing = false
            let completions = dismissalCompletions
            dismissalCompletions.removeAll()
            for completion in completions { completion() }
        }
    }
#endif
