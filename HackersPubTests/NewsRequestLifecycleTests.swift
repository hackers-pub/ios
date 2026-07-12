@testable import HackersPub
import Testing

struct NewsRequestLifecycleTests {
    @Test func cancellingCurrentInitialRequestReleasesLoadingAndReopensInitialGate() {
        var state = NewsRequestLifecycle()
        let requestID = state.begin()

        #expect(state.isLoading)
        #expect(!state.hasLoadedInitial)

        state.finish(requestID: requestID, outcome: .cancelled)

        #expect(!state.isLoading)
        #expect(state.shouldLoadInitial)
        #expect(state.errorMessage == nil)
    }

    @Test func staleCompletionCannotClearNewerRequestLoading() {
        var state = NewsRequestLifecycle()
        let staleRequestID = state.begin()
        let currentRequestID = state.begin()

        state.finish(requestID: staleRequestID, outcome: .success)

        #expect(state.isLoading)
        #expect(state.currentRequestID == currentRequestID)
        #expect(!state.hasLoadedInitial)

        state.finish(requestID: currentRequestID, outcome: .success)

        #expect(!state.isLoading)
        #expect(state.hasLoadedInitial)
        #expect(!state.shouldLoadInitial)
    }

    @Test func currentFailureReleasesLoadingWithoutClosingInitialGate() {
        var state = NewsRequestLifecycle()
        let requestID = state.begin()

        state.finish(requestID: requestID, outcome: .failure("offline"))

        #expect(!state.isLoading)
        #expect(!state.hasLoadedInitial)
        #expect(state.shouldLoadInitial)
        #expect(state.errorMessage == "offline")
    }
}

struct NewsAdminLoadStateTests {
    @Test func initialFailureRecordsAttemptWithoutMarkingAdminStateLoaded() {
        var state = NewsAdminLoadState()
        let requestID = state.begin()

        state.finish(requestID: requestID, outcome: .failure("offline"))

        #expect(state.hasAttemptedInitialLoad)
        #expect(!state.hasLoadedInitial)
        #expect(!state.isLoading)
        #expect(state.showsInitialFailure)
        #expect(state.initialErrorMessage == "offline")
    }

    @Test func actionFailureAfterInitialSuccessPreservesLoadedAdminState() {
        var state = NewsAdminLoadState()
        let initialRequestID = state.begin()
        state.finish(requestID: initialRequestID, outcome: .success)

        state.recordActionFailure("could not recompute")

        #expect(state.hasAttemptedInitialLoad)
        #expect(state.hasLoadedInitial)
        #expect(!state.showsInitialFailure)
        #expect(state.actionErrorMessage == "could not recompute")
    }
}

struct NewsModerationPresentationStateTests {
    @Test func authorizationFailureRemovesModeratorAffordances() throws {
        var state = NewsModerationPresentationState(isModerator: true)

        state.record(.notAuthorized)

        #expect(state.error == .notAuthorized)
        #expect(!state.isModerator)
        #expect(try !#require(state.error?.canRetry))
    }

    @Test func authenticationFailureAlsoRemovesModeratorAffordances() throws {
        var state = NewsModerationPresentationState(isModerator: true)

        state.record(.notAuthenticated)

        #expect(state.error == .notAuthenticated)
        #expect(!state.isModerator)
        #expect(try !#require(state.error?.canRetry))
    }

    @Test func transientResponseFailureKeepsModeratorAffordancesAndCanRetry() throws {
        var state = NewsModerationPresentationState(isModerator: true)

        state.record(.graphQLError("server unavailable"))

        #expect(state.error == .graphQLError("server unavailable"))
        #expect(state.isModerator)
        #expect(try #require(state.error?.canRetry))
    }

    @Test func missingMutationResultStaysRetryableWithoutChangingModeratorStatus() throws {
        var state = NewsModerationPresentationState(isModerator: true)

        state.record(.missingResult)

        #expect(state.error == .missingResult)
        #expect(state.isModerator)
        #expect(try #require(state.error?.canRetry))
    }
}
