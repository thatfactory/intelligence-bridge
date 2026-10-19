#if os(iOS)
    public import SwiftUI

    extension View {
        /// Presents the native editor with confirmed opening and completed-dismissal callbacks.
        ///
        /// The opening deadline includes waiting for the view to enter a window, and stops as soon as
        /// UIKit confirms presentation. It never limits editing or image generation. Consume the result's
        /// temporary file synchronously in `onCompletion`, before the native editor is dismissed.
        /// Completion/cancellation is followed by `onDismissed`; launch failures are delivered after native
        /// cleanup, immediately before `onDismissed`. Keep this modifier mounted until dismissal finishes.
        @MainActor public func imagePlaygroundBridgePresentation(
            isPresented: Binding<Bool>,
            request: ImagePlaygroundBridgeRequest,
            openingTimeout: Duration = .seconds(12),
            onOpened: @escaping @MainActor () -> Void,
            onCompletion: @escaping @MainActor (ImagePlaygroundBridgeResult) -> Void,
            onCancellation: @escaping @MainActor () -> Void,
            onLaunchFailure: @escaping @MainActor (ImagePlaygroundBridgeLaunchFailure) -> Void,
            onDismissed: @escaping @MainActor () -> Void
        ) -> some View {
            background {
                ImagePlaygroundPresentationAdapter(
                    isPresented: isPresented, request: request, openingTimeout: openingTimeout,
                    onOpened: onOpened, onCompletion: onCompletion, onCancellation: onCancellation,
                    onLaunchFailure: onLaunchFailure, onDismissed: onDismissed
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }
#endif
