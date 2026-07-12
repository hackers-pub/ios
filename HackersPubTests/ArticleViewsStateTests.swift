@testable import HackersPub
import Testing

struct ArticleDraftListFailureRouteTests {
    @Test func failedInitialLoadsUseTheEmptyStateWhileFailedRefreshesKeepLoadedDraftsVisible() {
        #expect(ArticleDraftListFailureRoute.resolve(hasLoadedDrafts: false) == .initialLoad)
        #expect(ArticleDraftListFailureRoute.resolve(hasLoadedDrafts: true) == .retainedList)
    }
}

struct ArticleDraftDeleteOutcomeTests {
    @Test func responseErrorsAndMissingOrUnionPayloadsDoNotDeleteTheLocalDraft() {
        #expect(
            ArticleDraftDeleteOutcome.resolve(hasResponseErrors: false, hasDeletePayload: true) == .deleted
        )
        #expect(
            ArticleDraftDeleteOutcome.resolve(hasResponseErrors: true, hasDeletePayload: true) == .failed
        )
        #expect(
            ArticleDraftDeleteOutcome.resolve(hasResponseErrors: false, hasDeletePayload: false) == .failed
        )
    }
}

@MainActor
struct ArticleDraftListLoaderTests {
    @Test func newerLoadCancelsAndOutranksAnOlderCompletion() async {
        let loader = ArticleDraftListLoader<ArticleDraftListItem>(nodeID: \.id)
        let firstRequest = ControlledDraftRequest<ArticleDraftListLoadResponse>()
        let secondRequest = ControlledDraftRequest<ArticleDraftListLoadResponse>()
        var firstObservedCancellation = false

        let firstTask = Task {
            await loader.load(intent: .automatic) {
                let response = await firstRequest.run()
                firstObservedCancellation = Task.isCancelled
                return response
            }
        }
        await firstRequest.waitUntilStarted()

        let secondTask = Task {
            await loader.load(intent: .automatic) {
                await secondRequest.run()
            }
        }
        await secondRequest.waitUntilStarted()

        secondRequest.resume(returning: .success([draft(id: "new")]))
        await secondTask.value
        firstRequest.resume(returning: .success([draft(id: "old")]))
        await firstTask.value

        #expect(firstObservedCancellation)
        #expect(loader.drafts.map(\.id) == ["new"])
        #expect(!loader.isLoading)
    }

    @Test func successfulDeleteTombstoneFiltersALoadAlreadyInFlight() async {
        let loader = ArticleDraftListLoader<ArticleDraftListItem>(nodeID: \.id)
        await loader.load(intent: .automatic) {
            .success([draft(id: "delete-me"), draft(id: "keep-me")])
        }

        let loadRequest = ControlledDraftRequest<ArticleDraftListLoadResponse>()
        let loadTask = Task {
            await loader.load(intent: .automatic) {
                await loadRequest.run()
            }
        }
        await loadRequest.waitUntilStarted()

        let deleteRequest = ControlledDraftRequest<ArticleDraftListDeleteResponse>()
        let deleteTask = Task {
            await loader.delete(id: "delete-me") {
                await deleteRequest.run()
            }
        }
        await deleteRequest.waitUntilStarted()
        deleteRequest.resume(returning: .deleted)
        await deleteTask.value

        loadRequest.resume(returning: .success([draft(id: "delete-me"), draft(id: "keep-me")]))
        await loadTask.value

        #expect(loader.drafts.map(\.id) == ["keep-me"])
        #expect(loader.hasDeletionTombstone(for: "delete-me"))
    }

    @Test func explicitRefreshClearsATombstoneOnlyAfterTheServerOmitsTheDraft() async {
        let loader = ArticleDraftListLoader<ArticleDraftListItem>(nodeID: \.id)
        await loader.load(intent: .automatic) {
            .success([draft(id: "delete-me"), draft(id: "keep-me")])
        }
        await loader.delete(id: "delete-me") { .deleted }

        await loader.load(intent: .explicitRefresh) {
            .success([draft(id: "delete-me"), draft(id: "keep-me")])
        }
        #expect(loader.drafts.map(\.id) == ["keep-me"])
        #expect(loader.hasDeletionTombstone(for: "delete-me"))

        await loader.load(intent: .explicitRefresh) {
            .success([draft(id: "keep-me")])
        }
        #expect(loader.drafts.map(\.id) == ["keep-me"])
        #expect(!loader.hasDeletionTombstone(for: "delete-me"))
    }

    @Test func failedDeleteKeepsTheDraftAndExposesARetryableFailure() async {
        let loader = ArticleDraftListLoader<ArticleDraftListItem>(nodeID: \.id)
        await loader.load(intent: .automatic) {
            .success([draft(id: "keep-me")])
        }

        await loader.delete(id: "keep-me") { .failed }

        #expect(loader.drafts.map(\.id) == ["keep-me"])
        #expect(loader.actionFailure == .delete(id: "keep-me"))
        #expect(!loader.hasDeletionTombstone(for: "keep-me"))
    }

    private func draft(id: String) -> ArticleDraftListItem {
        ArticleDraftListItem(id: id, title: id, tags: [], updated: "2026-07-12T00:00:00Z")
    }
}

@MainActor
private final class ControlledDraftRequest<Value> {
    private var resultContinuation: CheckedContinuation<Value, Never>?
    private var startContinuations: [CheckedContinuation<Void, Never>] = []
    private var started = false

    func run() async -> Value {
        started = true
        let waiters = startContinuations
        startContinuations.removeAll()
        waiters.forEach { $0.resume() }
        return await withCheckedContinuation { continuation in
            resultContinuation = continuation
        }
    }

    func waitUntilStarted() async {
        guard !started else { return }
        await withCheckedContinuation { continuation in
            startContinuations.append(continuation)
        }
    }

    func resume(returning value: Value) {
        resultContinuation?.resume(returning: value)
        resultContinuation = nil
    }
}

struct ArticleEditorTargetTests {
    @Test func distinguishesNewArticlesFromExistingDraftsWithoutAnEmptyIdentifierSentinel() {
        #expect(ArticleEditorTarget.new.draftID == nil)
        #expect(ArticleEditorTarget.draft("draft-id").draftID == "draft-id")
        #expect(ArticleEditorTarget.new.id != ArticleEditorTarget.draft("draft-id").id)
    }
}
