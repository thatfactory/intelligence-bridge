#if os(iOS)
    import ImagePlayground
    import UIKit

    @MainActor
    final class ImagePlaygroundUIKitOperations: NSObject, ImagePlaygroundPresentationOperations,
        ImagePlaygroundViewController.Delegate, UIAdaptivePresentationControllerDelegate
    {
        weak var anchor: ImagePlaygroundPresentationAnchor?
        private var controller: ImagePlaygroundViewController?
        private var onResult: @MainActor (URL) -> Void = { _ in }
        private var onCancelled: @MainActor () -> Void = {}

        var snapshot: ImagePlaygroundPresentationSnapshot {
            ImagePlaygroundPresentationSnapshot(
                anchorIsReady: anchor?.hasAppeared == true && anchor?.viewIfLoaded?.window != nil
                    && anchor?.isBeingDismissed == false && anchor?.presentedViewController == nil
                    && anchor?.transitionCoordinator == nil,
                associated: controller != nil
                    && (controller?.presentingViewController != nil || anchor?.presentedViewController === controller),
                attached: controller?.viewIfLoaded?.window != nil,
                transitioning: controller?.isBeingPresented == true || controller?.isBeingDismissed == true
                    || controller?.transitionCoordinator != nil
            )
        }

        func prepare(
            request: ImagePlaygroundBridgeRequest,
            onResult: @escaping @MainActor (URL) -> Void,
            onCancelled: @escaping @MainActor () -> Void
        ) {
            let editor = ImagePlaygroundViewController()
            editor.concepts = request.concepts.map { concept in
                switch concept {
                case .extracted(let text, let title): .extracted(from: text, title: title)
                case .text(let text): .text(text)
                }
            }
            self.onResult = onResult
            self.onCancelled = onCancelled
            editor.delegate = self
            controller = editor
        }

        func present(completion: @escaping @MainActor () -> Void) {
            guard let controller, let anchor else { return }
            anchor.present(controller, animated: true, completion: completion)
            controller.presentationController?.delegate = self
        }

        func dismiss(animated: Bool, completion: @escaping @MainActor () -> Void) {
            controller?.delegate = nil
            controller?.dismiss(animated: animated, completion: completion)
        }

        func reset() {
            controller?.delegate = nil
            controller?.presentationController?.delegate = nil
            controller = nil
            onResult = { _ in }
            onCancelled = {}
        }

        func imagePlaygroundViewController(
            _ imagePlaygroundViewController: ImagePlaygroundViewController, didCreateImageAt imageURL: URL
        ) {
            guard controller === imagePlaygroundViewController else { return }
            onResult(imageURL)
        }

        func imagePlaygroundViewControllerDidCancel(_ imagePlaygroundViewController: ImagePlaygroundViewController) {
            guard controller === imagePlaygroundViewController else { return }
            onCancelled()
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            guard presentationController.presentedViewController === controller else { return }
            onCancelled()
        }
    }
#endif
