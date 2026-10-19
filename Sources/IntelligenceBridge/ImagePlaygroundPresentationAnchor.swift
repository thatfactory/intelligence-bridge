#if os(iOS)
    import UIKit

    /// An owned presentation anchor; it never inspects SwiftUI's hosting-controller hierarchy.
    @MainActor final class ImagePlaygroundPresentationAnchor: UIViewController {
        var becameUsable: (() -> Void)?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            becameUsable?()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            becameUsable?()
        }
    }
#endif
