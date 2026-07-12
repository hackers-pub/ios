@testable import HackersPub
import Testing

struct TimelineLifecycleStateTests {
    @Test func newOwnerDiscardsStaleInitialRequestAndRejectsItsCompletion() {
        var state = TimelineState<TimelineLifecycleFixture>()
        let staleRequest = state.beginInitial()
        #expect(staleRequest != nil)
        guard let staleRequest else { return }

        state.discardStaleRequestForNewOwner()
        let staleFinished = state.finish(staleRequest, outcome: .success)

        #expect(!state.isInitialLoading)
        #expect(state.shouldLoadInitial)
        #expect(!staleFinished)
        #expect(!state.hasLoadedInitial)

        let currentRequest = state.beginInitial()
        #expect(currentRequest != nil)
        #expect(currentRequest != staleRequest)
    }
}

private struct TimelineLifecycleFixture {}
