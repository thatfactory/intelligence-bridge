import Foundation

/// Observable state of the owned editor, without relying on presentation callback delivery.
struct ImagePlaygroundPresentationSnapshot {
    var anchorIsReady = false
    var associated = false
    var attached = false
    var transitioning = false

    var isOpen: Bool { associated && attached && !transitioning }
    var isDetached: Bool { !associated && !attached && !transitioning }
}

/// Internal UIKit operations seam; tests can control transitions without image generation.
@MainActor protocol ImagePlaygroundPresentationOperations: AnyObject {
    var snapshot: ImagePlaygroundPresentationSnapshot { get }
    func prepare(
        request: ImagePlaygroundBridgeRequest,
        onResult: @escaping @MainActor (URL) -> Void,
        onCancelled: @escaping @MainActor () -> Void
    )
    func present(completion: @escaping @MainActor () -> Void)
    func dismiss(animated: Bool, completion: @escaping @MainActor () -> Void)
    func reset()
}
