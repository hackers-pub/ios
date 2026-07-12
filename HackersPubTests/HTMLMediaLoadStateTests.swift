@testable import HackersPub
import Testing

struct HTMLMediaLoadStateTests {
    @Test
    func failureLeavesLoadingAndShowsRetryableState() {
        let state = HTMLMediaLoadReducer.reduce(.loading, event: .failed)

        #expect(state == .failed)
    }

    @Test
    func retryReturnsAFailedImageToLoading() {
        let state = HTMLMediaLoadReducer.reduce(.failed, event: .retry)

        #expect(state == .loading)
    }

    @Test
    func successKeepsTheImageVisibleAfterLoading() {
        let state = HTMLMediaLoadReducer.reduce(.loading, event: .succeeded)

        #expect(state == .loaded)
    }

    @Test
    func lateFailureFromThePreviousAttemptCannotReplaceARetry() {
        let initial = HTMLMediaLoadAttempt()
        let retry = initial.retrying()
        let result = retry.applying(.failed, from: initial.id)

        #expect(result.id == retry.id)
        #expect(result.state == .loading)
    }
}
