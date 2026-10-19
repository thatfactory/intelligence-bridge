import Foundation

/// Serializes opening, terminal delivery, and completed dismissal for one native presentation.
@MainActor final class ImagePlaygroundPresentationSession {
    enum Phase {
        case idle
        case opening
        case editing
        case closing
    }

    private(set) var phase: Phase = .idle
    private var attemptID: UUID?
    private var deadlineTask: Task<Void, Never>?
    private var onOpened: @MainActor () -> Void = {}
    private var onCompletion: @MainActor (ImagePlaygroundBridgeResult) -> Void = { _ in }
    private var onCancellation: @MainActor () -> Void = {}
    private var onFailure: @MainActor (ImagePlaygroundBridgeLaunchFailure) -> Void = { _ in }
    private var onDismissed: @MainActor () -> Void = {}
    private let driver: any ImagePlaygroundPresentationDriver
    private let wait: @Sendable (Duration) async throws -> Void

    init(
        driver: any ImagePlaygroundPresentationDriver,
        wait: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.driver = driver
        self.wait = wait
    }

    /// Accepts a request once; callbacks are immutable until this attempt has fully dismissed.
    func start(
        request: ImagePlaygroundBridgeRequest,
        available: Bool,
        openingTimeout: Duration,
        onOpened: @escaping @MainActor () -> Void,
        onCompletion: @escaping @MainActor (ImagePlaygroundBridgeResult) -> Void,
        onCancellation: @escaping @MainActor () -> Void,
        onFailure: @escaping @MainActor (ImagePlaygroundBridgeLaunchFailure) -> Void,
        onDismissed: @escaping @MainActor () -> Void
    ) {
        guard phase == .idle else { return }
        let id = UUID()
        attemptID = id
        phase = .opening
        self.onOpened = onOpened
        self.onCompletion = onCompletion
        self.onCancellation = onCancellation
        self.onFailure = onFailure
        self.onDismissed = onDismissed
        IntelligenceBridgeLogging.emit(.opening)
        guard available else {
            finish(id: id, failure: .unavailable)
            return
        }
        deadlineTask = Task { [weak self, wait] in
            guard !Task.isCancelled else { return }
            do { try await wait(openingTimeout) } catch { return }
            guard !Task.isCancelled else { return }
            self?.openingExpired(id: id)
        }
        driver.present(
            request: request,
            onOpened: { [weak self] in self?.opened(id: id) },
            onResult: { [weak self] url in self?.completed(url: url, id: id) },
            onCancelled: { [weak self] in self?.cancelled(id: id) }
        )
    }

    /// Cancels a requested presentation, including one still waiting for a window.
    func cancel() {
        guard let id = attemptID else { return }
        cancelled(id: id)
    }

    /// Releases native presentation when its SwiftUI anchor is removed, suppressing host callbacks.
    func invalidate() {
        if phase != .idle { IntelligenceBridgeLogging.emit(.invalidated) }
        deadlineTask?.cancel()
        deadlineTask = nil
        attemptID = nil
        phase = .idle
        clearCallbacks()
        driver.dismiss(completion: {})
    }

    private func opened(id: UUID) {
        guard attemptID == id, phase == .opening, driver.isOpen else { return }
        phase = .editing
        deadlineTask?.cancel()
        deadlineTask = nil
        IntelligenceBridgeLogging.emit(.opened)
        onOpened()
    }

    private func openingExpired(id: UUID) {
        guard attemptID == id, phase == .opening else { return }
        if driver.isOpen {
            opened(id: id)
        } else {
            finish(id: id, failure: .timedOut)
        }
    }

    private func completed(url: URL, id: UUID) {
        guard acceptsTerminal(id) else { return }
        phase = .closing
        deadlineTask?.cancel()
        // The host must consume the temporary URL before the native delegate returns.
        IntelligenceBridgeLogging.emit(.completed)
        onCompletion(ImagePlaygroundBridgeResult(temporaryURL: url))
        dismiss(id: id, failure: nil)
    }

    private func cancelled(id: UUID) {
        guard acceptsTerminal(id) else { return }
        phase = .closing
        deadlineTask?.cancel()
        IntelligenceBridgeLogging.emit(.cancelled)
        onCancellation()
        dismiss(id: id, failure: nil)
    }

    private func finish(id: UUID, failure: ImagePlaygroundBridgeLaunchFailure) {
        guard acceptsTerminal(id) else { return }
        phase = .closing
        deadlineTask?.cancel()
        IntelligenceBridgeLogging.emit(.launchFailed(failure))
        dismiss(id: id, failure: failure)
    }

    private func acceptsTerminal(_ id: UUID) -> Bool {
        attemptID == id && (phase == .opening || phase == .editing)
    }

    private func dismiss(id: UUID, failure: ImagePlaygroundBridgeLaunchFailure?) {
        driver.dismiss { [weak self] in
            guard let self, self.attemptID == id, self.phase == .closing else { return }
            self.attemptID = nil
            self.deadlineTask = nil
            let notifyFailure = self.onFailure
            let notifyDismissed = self.onDismissed
            self.clearCallbacks()
            self.phase = .idle
            IntelligenceBridgeLogging.emit(.dismissed)
            if let failure { notifyFailure(failure) }
            notifyDismissed()
        }
    }

    private func clearCallbacks() {
        onOpened = {}
        onCompletion = { _ in }
        onCancellation = {}
        onFailure = { _ in }
        onDismissed = {}
    }
}
