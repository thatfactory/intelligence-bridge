#if os(iOS)
    import UIKit

    /// An owned presentation anchor; it never inspects SwiftUI's hosting-controller hierarchy.
    @MainActor final class ImagePlaygroundPresentationAnchor: UIViewController {
        var becameUsable: (() -> Void)?
        private(set) var hasAppeared = false

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            hasAppeared = true
            becameUsable?()
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            hasAppeared = false
        }
    }
#endif
