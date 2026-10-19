#if os(iOS)
    import SwiftUI

    /// Retains one native driver/session across SwiftUI updates.
    struct ImagePlaygroundPresentationAdapter: UIViewControllerRepresentable {
        @Binding var isPresented: Bool
        let request: ImagePlaygroundBridgeRequest
        let openingTimeout: Duration
        let onOpened: @MainActor () -> Void
        let onCompletion: @MainActor (ImagePlaygroundBridgeResult) -> Void
        let onCancellation: @MainActor () -> Void
        let onLaunchFailure: @MainActor (ImagePlaygroundBridgeLaunchFailure) -> Void
        let onDismissed: @MainActor () -> Void

        func makeCoordinator() -> Coordinator { Coordinator() }

        func makeUIViewController(context: Context) -> ImagePlaygroundPresentationAnchor {
            let anchor = ImagePlaygroundPresentationAnchor()
            anchor.view.backgroundColor = .clear
            context.coordinator.driver.anchor = anchor
            anchor.becameUsable = { [weak driver = context.coordinator.driver] in driver?.presentIfReady() }
            return anchor
        }

        func updateUIViewController(_ anchor: ImagePlaygroundPresentationAnchor, context: Context) {
            let coordinator = context.coordinator
            // Defer observable host callbacks outside SwiftUI's update transaction.
            coordinator.updateTask?.cancel()
            coordinator.updateTask = Task { @MainActor in
                guard !Task.isCancelled else { return }
                if isPresented {
                    coordinator.session.start(
                        request: request,
                        available: ImagePlaygroundBridgeAvailability.current == .available,
                        openingTimeout: openingTimeout,
                        onOpened: onOpened,
                        onCompletion: onCompletion,
                        onCancellation: onCancellation,
                        onFailure: onLaunchFailure,
                        onDismissed: {
                            isPresented = false
                            onDismissed()
                        }
                    )
                    coordinator.driver.presentIfReady()
                } else {
                    coordinator.session.cancel()
                }
            }
        }

        static func dismantleUIViewController(_ anchor: ImagePlaygroundPresentationAnchor, coordinator: Coordinator) {
            coordinator.updateTask?.cancel()
            anchor.becameUsable = nil
            coordinator.session.invalidate()
        }

        @MainActor final class Coordinator {
            let driver: ImagePlaygroundUIKitDriver
            let session: ImagePlaygroundPresentationSession
            var updateTask: Task<Void, Never>?

            init() {
                driver = ImagePlaygroundUIKitDriver()
                session = ImagePlaygroundPresentationSession(driver: driver)
            }
        }
    }
#endif
