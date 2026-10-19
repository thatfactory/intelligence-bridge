import Foundation

/// The owned native controller boundary, replaceable in deterministic lifecycle tests.
@MainActor protocol ImagePlaygroundPresentationDriver: AnyObject {
    var isOpen: Bool { get }

    func present(
        request: ImagePlaygroundBridgeRequest,
        onOpened: @escaping @MainActor () -> Void,
        onResult: @escaping @MainActor (URL) -> Void,
        onCancelled: @escaping @MainActor () -> Void
    )

    func dismiss(completion: @escaping @MainActor () -> Void)
}
