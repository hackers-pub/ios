import Foundation
@testable import HackersPub
import Testing

struct TimelineFeedPresentationTests {
    @Test func emptyAndErrorStatesRetainRetryAndAsyncRefreshWiring() throws {
        var state = TimelineState<Fixture>()
        #expect(TimelineFeedPresentationState(timelineState: state).phase == .empty)

        let source = try timelineFeedPresentationSource()
        let componentStart = try #require(source.range(of: "struct TimelineFeedContent<"))
        let component = String(source[componentStart.lowerBound...])
        #expect(component.contains("LoadFailureView(message: errorMessage, retry: retry)"))
        #expect(component.contains("TimelineEmptyState(retry: retry, refresh: refresh)"))
        #expect(component.contains(".refreshable {\n            await refresh()\n        }"))

        let initial = state.beginInitial()
        #expect(TimelineFeedPresentationState(timelineState: state).phase == .initialLoading)

        guard let initial else { return }
        _ = state.finish(initial, outcome: .failure("offline"))
        #expect(TimelineFeedPresentationState(timelineState: state).phase == .emptyError("offline"))
    }

    @Test func refreshNewerAndOlderKeepContentAndDirectionalLoadingDistinct() {
        var state = TimelineState<Fixture>()
        guard let initial = state.beginInitial() else { return }
        _ = state.replaceFirstPage(
            [Fixture(id: "old", cursor: "old")],
            pageInfo: pageInfo(),
            identifier: \.id,
            for: initial
        )
        _ = state.finish(initial, outcome: .success)

        guard let refresh = state.beginRefresh() else { return }
        #expect(TimelineFeedPresentationState(timelineState: state).phase == .content)
        _ = state.mergeNewerPage(
            [Fixture(id: "new", cursor: "new")],
            page: TimelineNewerPage(nextCursor: "new", hasMoreNewer: true, fallbackEndCursor: "old"),
            cursor: \.cursor,
            identifier: \.id,
            for: refresh
        )
        _ = state.finish(refresh, outcome: .success)

        let ready = TimelineFeedPresentationState(timelineState: state)
        #expect(ready.showsLoadNewer)
        #expect(!ready.isLoadingNewer)
        #expect(!ready.isLoadingMore)

        guard let newer = state.beginNewer() else { return }
        let loadingNewer = TimelineFeedPresentationState(timelineState: state)
        #expect(loadingNewer.phase == .content)
        #expect(loadingNewer.isLoadingNewer)
        #expect(!loadingNewer.isLoadingMore)
        _ = state.finish(newer, outcome: .success)

        guard let older = state.beginMore() else { return }
        let loadingOlder = TimelineFeedPresentationState(timelineState: state)
        #expect(!loadingOlder.isLoadingNewer)
        #expect(loadingOlder.isLoadingMore)
    }

    private func pageInfo() -> TimelinePageInfo {
        TimelinePageInfo(
            hasPreviousPage: false,
            hasNextPage: true,
            startCursor: "old",
            endCursor: "old"
        )
    }

    private func timelineFeedPresentationSource() throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appending(path: "HackersPub/Views/TimelineFeedPresentation.swift"),
            encoding: .utf8
        )
    }
}

private struct Fixture: Equatable {
    let id: String
    let cursor: String
}
