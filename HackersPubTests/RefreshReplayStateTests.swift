@testable import HackersPub
import Testing

struct RefreshReplayStateTests {
    @Test func notificationDuringActiveRefreshSchedulesExactlyOneFollowUp() {
        var state = RefreshReplayState()

        state.request()
        let activeRevision = state.beginIfNeeded(isBusy: false)
        #expect(activeRevision != nil)
        guard let activeRevision else { return }

        state.request()
        state.request()
        let needsReplay = state.finish(activeRevision, cancelled: false)

        #expect(needsReplay)
        let replayRevision = state.beginIfNeeded(isBusy: false)
        #expect(replayRevision != nil)
        guard let replayRevision else { return }

        let needsAnotherReplay = state.finish(replayRevision, cancelled: false)
        #expect(!needsAnotherReplay)
        #expect(!state.hasPendingRefresh)
    }

    @Test func notificationWaitsUntilAnUnrelatedRefreshIsNoLongerBusy() {
        var state = RefreshReplayState()

        state.request()

        #expect(state.beginIfNeeded(isBusy: true) == nil)
        #expect(state.hasPendingRefresh)
        #expect(state.beginIfNeeded(isBusy: false) != nil)
    }

    @Test func cancellationDoesNotConsumePendingNotification() {
        var state = RefreshReplayState()

        state.request()
        let revision = state.beginIfNeeded(isBusy: false)
        #expect(revision != nil)
        guard let revision else { return }

        let shouldReplayImmediately = state.finish(revision, cancelled: true)
        #expect(!shouldReplayImmediately)
        #expect(state.hasPendingRefresh)
        #expect(state.beginIfNeeded(isBusy: false) != nil)
    }
}
