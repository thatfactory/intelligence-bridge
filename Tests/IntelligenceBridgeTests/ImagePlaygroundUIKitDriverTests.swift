import Foundation
import Testing

@testable import IntelligenceBridge

@Suite(.timeLimit(.minutes(1))) @MainActor
struct ImagePlaygroundUIKitDriverTests {
    @Test func unacknowledgedPresentationGetsBoundedCleanup() async {
        let f = Fixture()
        f.start()
        f.close()
        #expect(f.completed == 0)
        await f.clock.advance(20)
        await f.waitForFinished()
        #expect(f.completed == 1)
        #expect(f.operations.dismissals.isEmpty)
    }

    @Test func lateAssociationAfterCancellationIsDismissed() async {
        let f = Fixture()
        f.start()
        let oldCompletion = f.operations.presentation
        f.close()
        f.operations.snapshot.associated = true
        f.operations.snapshot.attached = true
        await f.clock.advance(1)
        while f.operations.dismissals.isEmpty { await Task.yield() }
        #expect(f.opened == 0)
        f.operations.snapshot = .init(anchorIsReady: true)
        await f.clock.advance(1)
        await f.waitForFinished()
        oldCompletion()
        #expect(f.completed == 1)
        #expect(f.opened == 0)
    }

    @Test func actualStateIsVisibleWithoutPresentationCompletion() {
        let f = Fixture()
        f.start()
        f.operations.snapshot.associated = true
        f.operations.snapshot.attached = true
        #expect(f.driver.isOpen)
        #expect(f.opened == 0)
    }

    @Test func cleanupSurvivesCoordinatorOwnerRelease() async {
        let clock = Clock()
        let operations = Operations()
        var driver: ImagePlaygroundUIKitDriver? = ImagePlaygroundUIKitDriver(
            operations: operations, wait: { await clock.wait() }
        )
        weak let retained = driver
        driver?.present(request: request, onOpened: {}, onResult: { _ in }, onCancelled: {})
        operations.snapshot.associated = true
        operations.snapshot.attached = true
        operations.snapshot.transitioning = true
        var completed = false
        driver?.dismiss { completed = true }
        driver = nil
        #expect(retained != nil)
        operations.snapshot.transitioning = false
        await clock.advance(1)
        while operations.dismissals.isEmpty { await Task.yield() }
        operations.snapshot = .init(anchorIsReady: true)
        await clock.advance(1)
        while !completed { await Task.yield() }
        while retained != nil { await Task.yield() }
        #expect(operations.resetCount == 1)
    }

    @Test func detachmentCompletesWithoutDismissalCallback() async {
        let f = Fixture()
        f.start()
        f.operations.snapshot.associated = true
        f.operations.snapshot.attached = true
        f.operations.presentation()
        f.close()
        #expect(f.operations.dismissals == [true])
        f.operations.snapshot = .init(anchorIsReady: true)
        await f.clock.advance(1)
        await f.waitForFinished()
        #expect(f.completed == 1)
    }

    @Test func staleCompletionCannotOpenNewAttempt() async {
        let f = Fixture()
        f.start()
        let oldCompletion = f.operations.presentation
        let oldResult = f.operations.result
        f.close()
        await f.clock.advance(20)
        await f.waitForFinished()
        f.start()
        f.operations.snapshot.associated = true
        f.operations.snapshot.attached = true
        oldCompletion()
        oldResult(URL(filePath: "/tmp/stale"))
        #expect(f.opened == 0)
        #expect(f.results == 0)
        #expect(f.driver.state == .presenting)
        f.operations.presentation()
        #expect(f.opened == 1)
    }

    @Test func stuckControllerIsEscalatedButNeverFalselyReportedDismissed() async {
        let f = Fixture()
        f.start()
        f.operations.snapshot.associated = true
        f.operations.snapshot.attached = true
        f.operations.snapshot.transitioning = true
        f.close()
        await f.clock.advance(20)
        while f.operations.dismissals.isEmpty { await Task.yield() }
        #expect(f.operations.dismissals == [false])
        #expect(f.completed == 0)
        #expect(f.driver.state == .closing)
    }

    @Test func waitsForConfirmedAnchorReadiness() {
        let f = Fixture()
        f.operations.snapshot.anchorIsReady = false
        f.start()
        #expect(f.operations.presentCount == 0)
        f.operations.snapshot.anchorIsReady = true
        f.driver.presentIfReady()
        f.driver.presentIfReady()
        #expect(f.operations.presentCount == 1)
    }

    private var request: ImagePlaygroundBridgeRequest { .init(concepts: [.text("prompt")]) }

    @MainActor private final class Fixture {
        let operations = Operations()
        let clock = Clock()
        let driver: ImagePlaygroundUIKitDriver
        var opened = 0
        var completed = 0
        var results = 0
        init() {
            let clock = clock
            driver = ImagePlaygroundUIKitDriver(operations: operations, wait: { await clock.wait() })
        }
        func start() {
            driver.present(
                request: .init(concepts: [.text("prompt")]),
                onOpened: { [unowned self] in opened += 1 },
                onResult: { [unowned self] _ in results += 1 }, onCancelled: {}
            )
        }
        func close() { driver.dismiss { [unowned self] in completed += 1 } }
        func waitForFinished() async {
            while driver.state != .finished { await Task.yield() }
        }
    }

    @MainActor private final class Operations: ImagePlaygroundPresentationOperations {
        var snapshot = ImagePlaygroundPresentationSnapshot(anchorIsReady: true)
        var presentation: @MainActor () -> Void = {}
        var result: @MainActor (URL) -> Void = { _ in }
        var presentCount = 0
        var dismissals: [Bool] = []
        var resetCount = 0
        func prepare(
            request: ImagePlaygroundBridgeRequest,
            onResult: @escaping @MainActor (URL) -> Void,
            onCancelled: @escaping @MainActor () -> Void
        ) { result = onResult }
        func present(completion: @escaping @MainActor () -> Void) {
            presentCount += 1
            presentation = completion
        }
        func dismiss(animated: Bool, completion: @escaping @MainActor () -> Void) { dismissals.append(animated) }
        func reset() { resetCount += 1 }
    }

    private actor Clock {
        private var continuation: CheckedContinuation<Void, Never>?
        func wait() async { await withCheckedContinuation { continuation = $0 } }
        func advance(_ ticks: Int) async {
            for _ in 0..<ticks {
                while continuation == nil { await Task.yield() }
                let current = continuation
                continuation = nil
                current?.resume()
            }
        }
    }
}
