@testable import HackersPub
import Testing

struct BookmarkFilterRequestCoordinatorTests {
    @Test("SOC-2: selecting a new filter invalidates older, newer, and refresh tokens")
    func filterChangeInvalidatesEveryRequestKind() {
        var coordinator = BookmarkFilterRequestCoordinator(filterID: "all")
        let older = coordinator.begin(.older)
        let newer = coordinator.begin(.newer)
        let refresh = coordinator.begin(.refresh)

        coordinator.select(filterID: "articles")

        #expect(!coordinator.isCurrent(older))
        #expect(!coordinator.isCurrent(newer))
        #expect(!coordinator.isCurrent(refresh))
        let finishedOlder = coordinator.finish(older)
        let finishedNewer = coordinator.finish(newer)
        let finishedRefresh = coordinator.finish(refresh)
        #expect(!finishedOlder)
        #expect(!finishedNewer)
        #expect(!finishedRefresh)
    }

    @Test("SOC-2: A to B to A rejects stale responses even when every filter uses a different operation kind")
    func filterEpochRejectsABAReturns() {
        var coordinator = BookmarkFilterRequestCoordinator(filterID: "all")
        let originalAll = coordinator.begin(.older)

        coordinator.select(filterID: "articles")
        let articles = coordinator.begin(.newer)
        coordinator.select(filterID: "all")
        let currentAll = coordinator.begin(.refresh)

        #expect(!coordinator.isCurrent(originalAll))
        #expect(!coordinator.isCurrent(articles))
        #expect(coordinator.isCurrent(currentAll))
        let finishedCurrentAll = coordinator.finish(currentAll)
        #expect(finishedCurrentAll)
    }

    @Test("SOC-2: an ArticleEditor refresh owns the list lifecycle after superseding older pagination")
    func articleEditorRefreshPreventsStaleOlderCleanup() {
        var coordinator = BookmarkFilterRequestCoordinator(filterID: "notes")
        let older = coordinator.begin(.older)
        var activeListTask: BookmarkFilterRequestToken? = older
        var isLoading = true
        var hasLoadedInitial = false

        let articleEditorRefresh = coordinator.begin(.refresh)
        activeListTask = articleEditorRefresh

        let staleOlderFinished = coordinator.finish(older)
        if staleOlderFinished {
            activeListTask = nil
            isLoading = false
            hasLoadedInitial = true
        }

        #expect(!staleOlderFinished)
        #expect(!coordinator.isCurrent(older))
        #expect(coordinator.isCurrent(articleEditorRefresh))
        #expect(activeListTask == articleEditorRefresh)
        #expect(isLoading)
        #expect(!hasLoadedInitial)
    }

    @Test("SOC-2: every bookmark operation conflicts with the previous operation regardless of kind")
    func crossKindRequestsHaveSingleGlobalOwnership() {
        var coordinator = BookmarkFilterRequestCoordinator(filterID: "all")
        let initial = coordinator.begin(.initial)
        let newer = coordinator.begin(.newer)
        let older = coordinator.begin(.older)
        let refresh = coordinator.begin(.refresh)

        #expect(!coordinator.isCurrent(initial))
        #expect(!coordinator.isCurrent(newer))
        #expect(!coordinator.isCurrent(older))
        #expect(coordinator.isCurrent(refresh))
    }

    @Test("SOC-2: the filter token carries the selected filter and monotonically advances on picker changes")
    func filterTokenPreservesQueryFilterIdentity() {
        var coordinator = BookmarkFilterRequestCoordinator(filterID: "all")
        let all = coordinator.begin(.initial)
        coordinator.select(filterID: "articles")
        let articles = coordinator.begin(.initial)

        #expect(all.filterID == "all")
        #expect(articles.filterID == "articles")
        #expect(articles.epoch > all.epoch)
    }

    @Test("SOC-8/POST-11: content removal fences an active request without changing its filter")
    func contentRemovalInvalidatesActiveRequestWhileRetainingFilter() {
        var coordinator = BookmarkFilterRequestCoordinator(filterID: "all")
        let staleRequest = coordinator.begin(.older)

        coordinator.invalidateActiveRequests()

        #expect(coordinator.selectedFilterID == "all")
        #expect(!coordinator.isCurrent(staleRequest))
        let finishedStaleRequest = coordinator.finish(staleRequest)
        #expect(!finishedStaleRequest)

        let replacement = coordinator.begin(.refresh)
        #expect(replacement.filterID == "all")
        #expect(replacement.epoch > staleRequest.epoch)
        #expect(coordinator.isCurrent(replacement))
    }
}
