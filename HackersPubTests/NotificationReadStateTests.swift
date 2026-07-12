import Foundation
@testable import HackersPub
import Testing

@MainActor
struct NotificationReadStateTests {
    private let session = NotificationReadSession(accountID: "viewer", sessionToken: "session-a")

    @Test func keepsTheServerBadgeUntilMarkSucceedsAndThenUsesTheRefreshedCount() async {
        let backend = ControlledNotificationMarkBackend()
        var fetchedCounts = [7, 2]
        let state = NotificationReadState(
            mark: backend.mark,
            fetchUnreadCount: { _ in fetchedCounts.removeFirst() }
        )

        await state.refreshUnreadCount(for: session)
        let marking = Task { @MainActor in
            await state.markDisplayedNotificationsAsRead(
                upTo: "newest-visible-uuid",
                for: session
            )
        }
        await backend.waitForMarkCount(1)

        #expect(backend.markedUUIDs == ["newest-visible-uuid"])
        #expect(state.unreadCount == 7)
        #expect(state.presentation.badgeCount == 7)

        backend.succeed(request: 0)
        let outcome = await marking.value

        #expect(outcome == .marked)
        #expect(state.unreadCount == 2)
        #expect(state.presentation.badgeCount == 2)
        #expect(!state.presentation.showsReadRetry)
    }

    @Test func twoReconstructedViewsCoalesceTheSameVisibleBoundaryGlobally() async {
        let backend = ControlledNotificationMarkBackend()
        let state = NotificationReadState(
            mark: backend.mark,
            fetchUnreadCount: { _ in 1 }
        )

        let firstView = Task { @MainActor in
            await state.markDisplayedNotificationsAsRead(upTo: "uuid-a", for: session)
        }
        await backend.waitForMarkCount(1)

        let reconstructedViewOutcome = await state.markDisplayedNotificationsAsRead(
            upTo: "uuid-a",
            for: session
        )
        #expect(reconstructedViewOutcome == .ignored)
        #expect(backend.markedUUIDs == ["uuid-a"])

        backend.succeed(request: 0)
        let firstViewOutcome = await firstView.value

        #expect(firstViewOutcome == .marked)
        #expect(backend.markedUUIDs == ["uuid-a"])
        #expect(state.unreadCount == 1)
    }

    @Test func queuesOnlyTheLatestBoundaryWhileAnOlderMarkIsInFlight() async {
        let backend = ControlledNotificationMarkBackend()
        let state = NotificationReadState(
            mark: backend.mark,
            fetchUnreadCount: { _ in 0 }
        )

        let processing = Task { @MainActor in
            await state.markDisplayedNotificationsAsRead(upTo: "uuid-a", for: session)
        }
        await backend.waitForMarkCount(1)

        let middleOutcome = await state.markDisplayedNotificationsAsRead(upTo: "uuid-b", for: session)
        let latestOutcome = await state.markDisplayedNotificationsAsRead(upTo: "uuid-c", for: session)
        #expect(middleOutcome == .ignored)
        #expect(latestOutcome == .ignored)
        #expect(backend.markedUUIDs == ["uuid-a"])

        backend.succeed(request: 0)
        await backend.waitForMarkCount(2)
        #expect(backend.markedUUIDs == ["uuid-a", "uuid-c"])

        backend.succeed(request: 1)
        let outcome = await processing.value

        #expect(outcome == .marked)
        #expect(state.unreadCount == 0)
        #expect(!state.isMarkingNotificationsRead)
    }

    @Test func coalescingKeyIncludesTheAccountSession() async {
        let backend = ControlledNotificationMarkBackend()
        let nextSession = NotificationReadSession(accountID: "viewer", sessionToken: "session-b")
        let state = NotificationReadState(
            mark: backend.mark,
            fetchUnreadCount: { session in session == nextSession ? 2 : 9 }
        )

        let staleSessionMark = Task { @MainActor in
            await state.markDisplayedNotificationsAsRead(upTo: "same-uuid", for: session)
        }
        await backend.waitForMarkCount(1)

        let currentSessionMark = Task { @MainActor in
            await state.markDisplayedNotificationsAsRead(upTo: "same-uuid", for: nextSession)
        }
        await backend.waitForMarkCount(2)
        #expect(backend.markedUUIDs == ["same-uuid", "same-uuid"])

        backend.succeed(request: 1)
        let currentOutcome = await currentSessionMark.value
        backend.succeed(request: 0)
        let staleOutcome = await staleSessionMark.value

        #expect(currentOutcome == .marked)
        #expect(staleOutcome == .ignored)
        #expect(state.unreadCount == 2)
        #expect(state.presentation.badgeCount == 2)
    }

    @Test func failurePreservesBadgePresentationAndAllowsTheSameBoundaryToRetry() async {
        let backend = ControlledNotificationMarkBackend()
        var fetchedCounts = [4, 1]
        let state = NotificationReadState(
            mark: backend.mark,
            fetchUnreadCount: { _ in fetchedCounts.removeFirst() }
        )
        await state.refreshUnreadCount(for: session)

        let failing = Task { @MainActor in
            await state.markDisplayedNotificationsAsRead(upTo: "uuid-a", for: session)
        }
        await backend.waitForMarkCount(1)
        backend.fail(request: 0, with: NotificationReadStateTestError.markFailed)
        let failed = await failing.value

        #expect(failed == .failed(NotificationReadStateTestError.markFailed.localizedDescription))
        #expect(state.presentation.badgeCount == 4)
        #expect(state.presentation.showsReadRetry)
        #expect(state.presentation.readErrorMessage != nil)

        let retrying = Task { @MainActor in
            await state.markDisplayedNotificationsAsRead(upTo: "uuid-a", for: session)
        }
        await backend.waitForMarkCount(2)
        backend.succeed(request: 1)
        let retried = await retrying.value

        #expect(retried == .marked)
        #expect(backend.markedUUIDs == ["uuid-a", "uuid-a"])
        #expect(state.presentation.badgeCount == 1)
        #expect(!state.presentation.showsReadRetry)
        #expect(state.presentation.readErrorMessage == nil)
    }

    @Test func preservesTheBadgeWhenThePostMarkCountRefreshFails() async {
        var fetchCount = 0
        let state = NotificationReadState(
            mark: { _ in },
            fetchUnreadCount: { _ in
                fetchCount += 1
                if fetchCount == 2 {
                    throw NotificationReadStateTestError.countRefreshFailed
                }
                return 4
            }
        )
        await state.refreshUnreadCount(for: session)

        let outcome = await state.markDisplayedNotificationsAsRead(upTo: "uuid-a", for: session)

        let didFail: Bool
        if case .failed = outcome {
            didFail = true
        } else {
            didFail = false
        }
        #expect(didFail)
        #expect(state.unreadCount == 4)
        #expect(state.presentation.badgeCount == 4)
        #expect(state.presentation.showsReadRetry)
    }

    @Test func ignoresCountResponsesThatStartedWhileAReadMarkWasInFlight() async {
        let backend = ControlledNotificationMarkBackend()
        var fetchedCounts = [6, 1]
        let state = NotificationReadState(
            mark: backend.mark,
            fetchUnreadCount: { _ in fetchedCounts.removeFirst() }
        )
        await state.refreshUnreadCount(for: session)

        let marking = Task { @MainActor in
            await state.markDisplayedNotificationsAsRead(upTo: "uuid-a", for: session)
        }
        await backend.waitForMarkCount(1)
        let inFlightCountRequest = state.beginUnreadRequest(for: session)
        backend.succeed(request: 0)
        let outcome = await marking.value

        #expect(outcome == .marked)
        #expect(state.unreadCount == 1)
        #expect(inFlightCountRequest != nil)
        guard let inFlightCountRequest else { return }
        #expect(state.applyUnreadCount(6, for: inFlightCountRequest) == false)
        #expect(state.unreadCount == 1)
    }

    @Test func ignoresStaleUnreadResponsesAndSessionChanges() {
        let state = NotificationReadState()
        let firstRequest = state.beginUnreadRequest(for: session)
        let latestRequest = state.beginUnreadRequest(for: session)

        #expect(firstRequest != nil)
        #expect(latestRequest != nil)
        guard let firstRequest, let latestRequest else { return }
        #expect(state.applyUnreadCount(8, for: firstRequest) == false)
        #expect(state.unreadCount == nil)
        #expect(state.applyUnreadCount(3, for: latestRequest) == true)
        #expect(state.unreadCount == 3)

        let staleRequest = state.beginUnreadRequest(for: session)
        let nextSession = NotificationReadSession(accountID: "viewer", sessionToken: "session-b")
        _ = state.beginUnreadRequest(for: nextSession)

        guard let staleRequest else { return }
        #expect(state.applyUnreadCount(1, for: staleRequest) == false)
        #expect(state.unreadCount == nil)
        #expect(state.presentation.badgeCount == 0)
    }

    @Test func ignoresCancelledReadMarkRequestsWithoutChangingTheBadge() async {
        let state = NotificationReadState(
            mark: { _ in
                try await Task.sleep(nanoseconds: 1_000_000_000)
            },
            fetchUnreadCount: { _ in 5 }
        )
        await state.refreshUnreadCount(for: session)

        let task = Task { @MainActor in
            await state.markDisplayedNotificationsAsRead(upTo: "uuid-a", for: session)
        }
        task.cancel()

        let outcome = await task.value
        #expect(outcome == .ignored)
        #expect(state.unreadCount == 5)
        #expect(state.markReadErrorMessage == nil)
        #expect(!state.isMarkingNotificationsRead)
    }

    private enum NotificationReadStateTestError: LocalizedError {
        case markFailed
        case countRefreshFailed

        var errorDescription: String? {
            switch self {
            case .markFailed:
                return "mark failed"
            case .countRefreshFailed:
                return "count refresh failed"
            }
        }
    }
}

@MainActor
private final class ControlledNotificationMarkBackend {
    private var continuations: [CheckedContinuation<Void, any Error>] = []
    private(set) var markedUUIDs: [String] = []

    func mark(_ notificationUUID: String) async throws {
        markedUUIDs.append(notificationUUID)
        try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitForMarkCount(_ count: Int) async {
        while markedUUIDs.count < count {
            await Task.yield()
        }
    }

    func succeed(request: Int) {
        continuations[request].resume()
    }

    func fail(request: Int, with error: any Error) {
        continuations[request].resume(throwing: error)
    }
}
