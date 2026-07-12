import Foundation
@testable import HackersPub
import Testing

@MainActor
struct TimelinePartialRefreshTests {
    private let partialWarningMessage = "Some posts could not be refreshed. Retry to load the complete timeline."

    @Test func laterTransportFailureReturnsUsableRowsWithAWarningAndPreservesExistingExtent() async throws {
        var requestedCursors: [String?] = []
        let coordinator = TimelineRefreshCoordinator<PartialRefreshFixture>(
            pageSize: 2,
            identifier: \.id,
            partialFailureMessage: partialWarningMessage
        ) { cursor, _ in
            requestedCursors.append(cursor)
            guard cursor == nil else { throw PartialRefreshTestError(message: "offline") }
            return page(
                [fixture("new"), fixture("a", title: "updated a")],
                hasNextPage: true,
                startCursor: "new",
                endCursor: "fresh-2"
            )
        }
        var state = loadedState([
            fixture("a", title: "old a"),
            fixture("b"),
            fixture("c"),
            fixture("d")
        ])
        let pendingRequest = state.beginRefresh()
        let request = try #require(pendingRequest)

        let snapshot = try await coordinator.load(targetCount: state.edges.count)

        #expect(requestedCursors == [nil, "fresh-2"])
        #expect(snapshot.edges.map(\.id) == ["new", "a"])
        #expect(snapshot.pageInfo.startCursor == "new")
        #expect(snapshot.pageInfo.endCursor == "fresh-2")
        #expect(snapshot.pageInfo.hasNextPage)
        #expect(!snapshot.isAuthoritative)
        #expect(snapshot.warning?.reason == .laterPageFailure)
        #expect(snapshot.warning?.message == partialWarningMessage)
        #expect(snapshot.warning?.debugMessage == "offline")

        let applied = state.applyRefreshSnapshot(snapshot, identifier: \.id, for: request)
        #expect(applied)
        #expect(state.edges.map(\.id) == ["new", "a", "b", "c", "d"])
        #expect(state.edges.first(where: { $0.id == "a" })?.title == "updated a")
        #expect(state.startCursor == "a")
        #expect(state.endCursor == "d")
        #expect(state.hasNextPage)

        _ = try state.finish(request, outcome: .partialSuccess(#require(snapshot.warningMessage)))
        #expect(state.errorMessage == partialWarningMessage)
        #expect(state.beginRefresh() != nil)
    }

    @Test func laterDataNilGraphQLFailureRetainsTheFirstUsablePageAndRawDiagnostic() async throws {
        let coordinator = TimelineRefreshCoordinator<PartialRefreshFixture>(
            pageSize: 2,
            identifier: \.id,
            partialFailureMessage: partialWarningMessage
        ) { cursor, _ in
            guard cursor == nil else {
                throw TimelineRefreshError(
                    userMessage: "Timeline data is unavailable.",
                    debugMessage: "raw GraphQL field error"
                )
            }
            return page(
                [fixture("new"), fixture("a")],
                hasNextPage: true,
                startCursor: "new",
                endCursor: "fresh-2"
            )
        }

        let snapshot = try await coordinator.load(targetCount: 4)

        #expect(snapshot.edges.map(\.id) == ["new", "a"])
        #expect(snapshot.pageInfo.startCursor == "new")
        #expect(snapshot.pageInfo.endCursor == "fresh-2")
        #expect(snapshot.warning?.reason == .laterPageFailure)
        #expect(snapshot.warning?.message == partialWarningMessage)
        #expect(snapshot.warning?.debugMessage == "raw GraphQL field error")
        #expect(snapshot.warning?.message != snapshot.warning?.debugMessage)
    }

    @Test func firstPageFailureRemainsAFullLocalizedFailure() async {
        var callCount = 0
        let coordinator = TimelineRefreshCoordinator<PartialRefreshFixture>(
            pageSize: 2,
            identifier: \.id,
            partialFailureMessage: partialWarningMessage
        ) { _, _ in
            callCount += 1
            throw TimelineRefreshError(
                userMessage: "Timeline data is unavailable.",
                debugMessage: "raw GraphQL field error"
            )
        }

        do {
            _ = try await coordinator.load(targetCount: 4)
            Issue.record("Expected the first-page failure to be thrown")
        } catch let error as TimelineRefreshError {
            #expect(error.errorDescription == "Timeline data is unavailable.")
            #expect(error.debugMessage == "raw GraphQL field error")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(callCount == 1)
    }

    @Test func firstPageDataWithGraphQLErrorsIsAUsableTypedPartialSnapshot() async throws {
        let graphQLWarning = TimelineRefreshWarning(
            reason: .graphQLPartialResponse,
            message: partialWarningMessage,
            debugMessage: "raw resolver error"
        )
        let coordinator = TimelineRefreshCoordinator<PartialRefreshFixture>(
            pageSize: 2,
            identifier: \.id,
            partialFailureMessage: partialWarningMessage
        ) { _, _ in
            page(
                [fixture("new"), fixture("a", title: "updated a")],
                hasNextPage: false,
                startCursor: "new",
                endCursor: "a",
                warning: graphQLWarning
            )
        }
        var state = loadedState([fixture("a", title: "old a"), fixture("b"), fixture("c")])
        let pendingRequest = state.beginRefresh()
        let request = try #require(pendingRequest)

        let snapshot = try await coordinator.load(targetCount: state.edges.count)

        #expect(!snapshot.isAuthoritative)
        #expect(snapshot.warning == graphQLWarning)
        #expect(snapshot.warningMessage == partialWarningMessage)
        #expect(snapshot.warningMessage != graphQLWarning.debugMessage)
        let applied = state.applyRefreshSnapshot(snapshot, identifier: \.id, for: request)
        #expect(applied)
        #expect(state.edges.map(\.id) == ["new", "a", "b", "c"])
        #expect(state.edges.first(where: { $0.id == "a" })?.title == "updated a")
        #expect(state.startCursor == "a")
        #expect(state.endCursor == "c")
    }

    @Test func cancellationAfterAUsablePageIsRethrownInsteadOfBecomingAPartialWarning() async {
        var requestedCursors: [String?] = []
        let coordinator = TimelineRefreshCoordinator<PartialRefreshFixture>(
            pageSize: 1,
            identifier: \.id,
            partialFailureMessage: partialWarningMessage
        ) { cursor, _ in
            requestedCursors.append(cursor)
            guard cursor == nil else { throw CancellationError() }
            return page(
                [fixture("new")],
                hasNextPage: true,
                startCursor: "new",
                endCursor: "fresh-1"
            )
        }

        do {
            _ = try await coordinator.load(targetCount: 2)
            Issue.record("Expected cancellation to be rethrown")
        } catch is CancellationError {
            // Expected.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(requestedCursors == [nil, "fresh-1"])
    }

    @Test func stalePartialSnapshotCannotCommitAfterANewerGenerationStarts() throws {
        var state = loadedState([fixture("current")])
        let pendingStaleRequest = state.beginRefresh()
        let staleRequest = try #require(pendingStaleRequest)
        _ = state.finish(staleRequest, outcome: .cancelled)
        #expect(state.beginRefresh() != nil)
        let staleSnapshot = TimelineRefreshSnapshot(
            edges: [fixture("stale")],
            pageInfo: pageInfo(hasNextPage: true, startCursor: "stale", endCursor: "stale-end"),
            completeness: .partial(
                TimelineRefreshWarning(
                    reason: .laterPageFailure,
                    message: partialWarningMessage,
                    debugMessage: "offline"
                )
            )
        )

        let applied = state.applyRefreshSnapshot(staleSnapshot, identifier: \.id, for: staleRequest)
        #expect(!applied)
        #expect(state.edges.map(\.id) == ["current"])
        #expect(state.startCursor == "current")
        #expect(state.endCursor == "current")
    }

    private func loadedState(_ edges: [PartialRefreshFixture]) -> TimelineState<PartialRefreshFixture> {
        var state = TimelineState<PartialRefreshFixture>()
        guard let request = state.beginInitial() else { return state }
        _ = state.replaceFirstPage(
            edges,
            pageInfo: pageInfo(
                hasNextPage: true,
                startCursor: edges.first?.cursor,
                endCursor: edges.last?.cursor
            ),
            identifier: \.id,
            for: request
        )
        _ = state.finish(request, outcome: .success)
        return state
    }

    private func fixture(
        _ id: String,
        title: String? = nil,
        cursor: String? = nil
    ) -> PartialRefreshFixture {
        PartialRefreshFixture(id: id, title: title ?? id, cursor: cursor ?? id)
    }

    private func page(
        _ edges: [PartialRefreshFixture],
        hasNextPage: Bool,
        startCursor: String?,
        endCursor: String?,
        warning: TimelineRefreshWarning? = nil
    ) -> TimelineRefreshPage<PartialRefreshFixture> {
        TimelineRefreshPage(
            edges: edges,
            pageInfo: pageInfo(
                hasNextPage: hasNextPage,
                startCursor: startCursor,
                endCursor: endCursor
            ),
            warning: warning
        )
    }

    private func pageInfo(
        hasNextPage: Bool,
        startCursor: String?,
        endCursor: String?
    ) -> TimelinePageInfo {
        TimelinePageInfo(
            hasPreviousPage: false,
            hasNextPage: hasNextPage,
            startCursor: startCursor,
            endCursor: endCursor
        )
    }
}

private struct PartialRefreshFixture: Equatable {
    let id: String
    let title: String
    let cursor: String
}

private struct PartialRefreshTestError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
