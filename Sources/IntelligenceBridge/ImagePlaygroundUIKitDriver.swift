import Foundation

/// Reconciles owned-controller observations even when UIKit omits a completion callback.
@MainActor final class ImagePlaygroundUIKitDriver: ImagePlaygroundPresentationDriver {
    enum State { case idle, waitingForAnchor, presenting, opened, closing, finished }

    let operations: any ImagePlaygroundPresentationOperations
    private(set) var state = State.idle
    private var attempt = UUID()
    private var presentationInvoked = false
    private var presentationCompleted = false
    private var observedAssociation = false
    private var dismissalRequested = false
    private var cleanupTicks = 0
    private var cleanupTask: Task<Void, Never>?
    private let wait: @Sendable () async -> Void
    private var dismissalCompletions: [@MainActor () -> Void] = []
    private var onOpened: @MainActor () -> Void = {}
    private var onResult: @MainActor (URL) -> Void = { _ in }
    private var onCancelled: @MainActor () -> Void = {}

    init(
        operations: any ImagePlaygroundPresentationOperations,
        wait: @escaping @Sendable () async -> Void = { try? await Task.sleep(for: .milliseconds(100)) }
    ) {
        self.operations = operations
        self.wait = wait
    }

    var isOpen: Bool { operations.snapshot.isOpen }

    func present(
        request: ImagePlaygroundBridgeRequest,
        onOpened: @escaping @MainActor () -> Void,
        onResult: @escaping @MainActor (URL) -> Void,
        onCancelled: @escaping @MainActor () -> Void
    ) {
        guard state == .idle || state == .finished else { return }
        attempt = UUID()
        let currentAttempt = attempt
        presentationInvoked = false
        presentationCompleted = false
        observedAssociation = false
        dismissalRequested = false
        cleanupTicks = 0
        state = .waitingForAnchor
        self.onOpened = onOpened
        self.onResult = onResult
        self.onCancelled = onCancelled
        operations.prepare(
            request: request,
            onResult: { [weak self] url in
                guard let self, self.attempt == currentAttempt, self.acceptsEditorCallbacks else { return }
                self.onResult(url)
            },
            onCancelled: { [weak self] in
                guard let self, self.attempt == currentAttempt, self.acceptsEditorCallbacks else { return }
                self.onCancelled()
            }
        )
        presentIfReady()
    }

    private var acceptsEditorCallbacks: Bool { state == .presenting || state == .opened }

    func presentIfReady() {
        guard state == .waitingForAnchor, operations.snapshot.anchorIsReady else { return }
        state = .presenting
        presentationInvoked = true
        let currentAttempt = attempt
        operations.present { [weak self] in
            guard let self, self.attempt == currentAttempt else { return }
            self.presentationCompleted = true
            if self.state == .closing {
                self.reconcileCleanup()
            } else if self.state == .presenting, self.isOpen {
                self.state = .opened
                self.onOpened()
            }
        }
    }

    /// A finite task owns cleanup independently of the SwiftUI coordinator and UIKit callbacks.
    func dismiss(completion: @escaping @MainActor () -> Void) {
        if state == .finished || state == .idle {
            completion()
            return
        }
        dismissalCompletions.append(completion)
        guard state != .closing else { return }
        state = .closing
        onOpened = {}
        onResult = { _ in }
        onCancelled = {}
        reconcileCleanup()
        guard state == .closing else { return }
        cleanupTask = Task { @MainActor [self] in
            for tick in 1...20 {
                guard state == .closing else { break }
                await wait()
                guard !Task.isCancelled, state == .closing else { break }
                cleanupTicks = tick
                reconcileCleanup()
            }
            if state == .closing { IntelligenceBridgeLogging.emit(.cleanupStalled) }
            cleanupTask = nil
        }
    }

    private func reconcileCleanup() {
        guard state == .closing else { return }
        let snapshot = operations.snapshot
        observedAssociation = observedAssociation || snapshot.associated || snapshot.attached
        if snapshot.isDetached {
            // An unacknowledged presentation gets the full two-second reconciliation window.
            let settled =
                !presentationInvoked || cleanupTicks >= 20
                || (cleanupTicks > 0 && (presentationCompleted || observedAssociation))
            if settled { finishDismissal() }
            return
        }
        guard snapshot.associated else { return }
        let escalate = cleanupTicks >= 10
        guard (!snapshot.transitioning && !dismissalRequested) || (escalate && cleanupTicks == 10) else { return }
        dismissalRequested = true
        let currentAttempt = attempt
        operations.dismiss(animated: !escalate) { [weak self] in
            guard let self, self.attempt == currentAttempt else { return }
            self.reconcileCleanup()
        }
    }

    private func finishDismissal() {
        state = .finished
        operations.reset()
        let completions = dismissalCompletions
        dismissalCompletions.removeAll()
        for completion in completions { completion() }
    }
}

#if os(iOS)
    extension ImagePlaygroundUIKitDriver {
        convenience init() { self.init(operations: ImagePlaygroundUIKitOperations()) }

        var anchor: ImagePlaygroundPresentationAnchor? {
            get { (operations as? ImagePlaygroundUIKitOperations)?.anchor }
            set { (operations as? ImagePlaygroundUIKitOperations)?.anchor = newValue }
        }
    }
#endif
