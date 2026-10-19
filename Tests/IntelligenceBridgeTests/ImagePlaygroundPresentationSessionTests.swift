import Foundation
import Testing

@testable import IntelligenceBridge

@Suite(.timeLimit(.minutes(1))) @MainActor
struct ImagePlaygroundPresentationSessionTests {
    @Test func unavailableReportsFailureOnlyAfterCleanup() {
        let fixture = Fixture()
        fixture.start(available: false)
        #expect(fixture.session.phase == .closing)
        #expect(fixture.events.isEmpty)
        fixture.driver.finishDismissal()
        #expect(fixture.events == ["unavailable", "dismissed"])
        #expect(fixture.driver.presentCount == 0)
    }

    @Test func neverAttachedTimesOutAndWaitsForDismissal() async {
        let fixture = Fixture()
        fixture.start()
        await fixture.clock.expireWhenScheduled()
        while fixture.session.phase == .opening { await Task.yield() }
        #expect(fixture.session.phase == .closing)
        #expect(fixture.events.isEmpty)
        fixture.driver.finishDismissal()
        #expect(fixture.events == ["timedOut", "dismissed"])
    }

    @Test func confirmedOpeningDoesNotExpireDuringEditing() async {
        let fixture = Fixture()
        fixture.start()
        await fixture.clock.waitUntilScheduled()
        fixture.driver.isOpen = true
        fixture.driver.opened()
        await fixture.clock.expireWhenScheduled()
        #expect(fixture.session.phase == .editing)
        #expect(fixture.events == ["opened"])
        fixture.session.cancel()
        fixture.driver.finishDismissal()
        #expect(fixture.events == ["opened", "cancelled", "dismissed"])
    }

    @Test func deadlineRechecksActuallyOpenedController() async {
        let fixture = Fixture()
        fixture.start()
        fixture.driver.isOpen = true
        await fixture.clock.expireWhenScheduled()
        while fixture.session.phase == .opening { await Task.yield() }
        #expect(fixture.session.phase == .editing)
        #expect(fixture.events == ["opened"])
        fixture.session.invalidate()
    }

    @Test func completionBeforeOpeningIsConsumedBeforeDismissalAndOnlyOnce() async {
        let fixture = Fixture()
        fixture.start()
        await fixture.clock.waitUntilScheduled()
        fixture.driver.result(URL(filePath: "/tmp/result"))
        fixture.driver.result(URL(filePath: "/tmp/duplicate"))
        fixture.driver.cancelled()
        await fixture.clock.expireWhenScheduled()
        #expect(fixture.events == ["completed"])
        #expect(fixture.session.phase == .closing)
        #expect(fixture.driver.dismissCount == 1)
        fixture.driver.finishDismissal()
        #expect(fixture.events == ["completed", "dismissed"])
    }

    @Test func cancellationBeforeOpeningWinsOverDeadline() async {
        let fixture = Fixture()
        fixture.start()
        await fixture.clock.waitUntilScheduled()
        fixture.session.cancel()
        fixture.driver.isOpen = true
        fixture.driver.opened()
        await fixture.clock.expireWhenScheduled()
        fixture.driver.finishDismissal()
        #expect(fixture.events == ["cancelled", "dismissed"])
    }

    @Test func staleCallbacksCannotTerminateNewAttempt() {
        let fixture = Fixture()
        fixture.start()
        let oldResult = fixture.driver.result
        let oldCancel = fixture.driver.cancelled
        let oldOpen = fixture.driver.opened
        fixture.session.cancel()
        fixture.driver.finishDismissal()
        fixture.events.removeAll()
        fixture.start()
        oldResult(URL(filePath: "/tmp/stale"))
        oldCancel()
        oldOpen()
        #expect(fixture.session.phase == .opening)
        #expect(fixture.events.isEmpty)
        fixture.session.invalidate()
    }

    @Test func removingAnchorSuppressesCallbacksAndCleansUp() {
        let fixture = Fixture()
        fixture.start()
        let oldResult = fixture.driver.result
        fixture.session.invalidate()
        oldResult(URL(filePath: "/tmp/stale"))
        fixture.driver.finishDismissal()
        #expect(fixture.events.isEmpty)
        #expect(fixture.session.phase == .idle)
    }

    @MainActor private final class Fixture {
        let driver = Driver()
        let clock = OpeningClock()
        let session: ImagePlaygroundPresentationSession
        var events: [String] = []

        init() {
            let clock = clock
            session = ImagePlaygroundPresentationSession(driver: driver, wait: { _ in await clock.wait() })
        }

        func start(available: Bool = true) {
            session.start(
                request: ImagePlaygroundBridgeRequest(concepts: [.text("prompt")]), available: available,
                openingTimeout: .seconds(12),
                onOpened: { [unowned self] in events.append("opened") },
                onCompletion: { [unowned self] _ in events.append("completed") },
                onCancellation: { [unowned self] in events.append("cancelled") },
                onFailure: { [unowned self] reason in events.append(reason == .timedOut ? "timedOut" : "unavailable") },
                onDismissed: { [unowned self] in events.append("dismissed") }
            )
        }
    }

    @MainActor private final class Driver: ImagePlaygroundPresentationDriver {
        var isOpen = false
        var presentCount = 0
        var dismissCount = 0
        var opened: @MainActor () -> Void = {}
        var result: @MainActor (URL) -> Void = { _ in }
        var cancelled: @MainActor () -> Void = {}
        var dismissal: @MainActor () -> Void = {}

        func present(
            request: ImagePlaygroundBridgeRequest,
            onOpened: @escaping @MainActor () -> Void,
            onResult: @escaping @MainActor (URL) -> Void,
            onCancelled: @escaping @MainActor () -> Void
        ) {
            presentCount += 1
            opened = onOpened
            result = onResult
            cancelled = onCancelled
        }

        func dismiss(completion: @escaping @MainActor () -> Void) {
            dismissCount += 1
            dismissal = completion
        }

        func finishDismissal() {
            isOpen = false
            let callback = dismissal
            dismissal = {}
            callback()
        }
    }

    private actor OpeningClock {
        private var continuation: CheckedContinuation<Void, Never>?

        func wait() async {
            await withCheckedContinuation { continuation = $0 }
        }

        func waitUntilScheduled() async {
            while continuation == nil { await Task.yield() }
        }

        func expireWhenScheduled() async {
            await waitUntilScheduled()
            continuation?.resume()
            continuation = nil
        }
    }
}
