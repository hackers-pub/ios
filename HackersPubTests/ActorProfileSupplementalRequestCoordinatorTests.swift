import Foundation
@testable import HackersPub
import Testing

struct ActorProfileTabRequestTests {
    @Test func switchingActorsRejectsEveryLateCompletionFromTheSuspendedActor() throws {
        for kind in ActorProfileTabRequestKind.allCases {
            var coordinator = ActorProfileTabRequestCoordinator(actorID: "actor-a")
            let optionalRequest = coordinator.begin(kind)
            let request = try #require(optionalRequest)
            var visibleActorState = "actor-b"

            coordinator.reset(actorID: "actor-b")
            if coordinator.isCurrent(request) {
                visibleActorState = "late-actor-a-\(kind)"
            }

            #expect(visibleActorState == "actor-b")
            #expect(!coordinator.isCurrent(request))
            let didFinish = coordinator.finish(request)
            #expect(!didFinish)
        }
    }

    @Test func switchingAwayAndBackStillRejectsTheOriginalActorsRequest() throws {
        var coordinator = ActorProfileTabRequestCoordinator(actorID: "actor-a")
        let optionalOriginal = coordinator.begin(.initial)
        let original = try #require(optionalOriginal)

        coordinator.reset(actorID: "actor-b")
        coordinator.reset(actorID: "actor-a")
        let optionalCurrent = coordinator.begin(.initial)
        let current = try #require(optionalCurrent)

        #expect(original.actorID == current.actorID)
        #expect(original.generation < current.generation)
        #expect(original.requestID < current.requestID)
        #expect(!coordinator.isCurrent(original))
        #expect(coordinator.isCurrent(current))
    }

    @Test func everySupplementalLoadKindCarriesIdentityGenerationAndAUniqueRequestID() throws {
        var coordinator = ActorProfileTabRequestCoordinator(actorID: "actor-a")
        var requestIDs: Set<UInt64> = []

        for kind in ActorProfileTabRequestKind.allCases {
            let optionalRequest = coordinator.begin(kind)
            let request = try #require(optionalRequest)
            #expect(request.actorID == "actor-a")
            #expect(request.generation == coordinator.generation)
            #expect(request.kind == kind)
            requestIDs.insert(request.requestID)
            let didFinish = coordinator.finish(request)
            #expect(didFinish)
        }

        #expect(requestIDs.count == ActorProfileTabRequestKind.allCases.count)
    }

    @Test func refreshDoesNotStartUntilTheCurrentSupplementalRequestFinishes() throws {
        var coordinator = ActorProfileTabRequestCoordinator(actorID: "actor-a")
        let initialRequest = coordinator.begin(.initial)
        let initial = try #require(initialRequest)

        #expect(coordinator.begin(.refresh) == nil)
        #expect(coordinator.isCurrent(initial))
        let didFinish = coordinator.finish(initial)
        #expect(didFinish)

        let refreshRequest = coordinator.begin(.refresh)
        let refresh = try #require(refreshRequest)
        #expect(refresh.kind == .refresh)
        #expect(refresh.generation == initial.generation + 1)
    }

    @Test func notesAndArticlesGuardSuccessErrorAndCancellationBeforeMutatingState() throws {
        let loadingSource = try repositorySource(
            at: "HackersPub/Views/Profile/ActorProfileSupplementalLoading.swift"
        )
        let viewSource = try repositorySource(at: "HackersPub/Views/Profile/ActorProfileView.swift")

        #expect(loadingSource.contains("notesRequestCoordinator.begin"))
        #expect(loadingSource.contains("articlesRequestCoordinator.begin"))
        #expect(loadingSource.contains("Task.checkCancellation()"))
        #expect(loadingSource.contains("actor.id == request.actorID"))
        #expect(loadingSource.contains("notesRequestCoordinator.isCurrent(request)"))
        #expect(loadingSource.contains("articlesRequestCoordinator.isCurrent(request)"))
        #expect(loadingSource.contains("catch is CancellationError"))
        #expect(viewSource.contains("notesRequestCoordinator.reset(actorID: actor.id)"))
        #expect(viewSource.contains("articlesRequestCoordinator.reset(actorID: actor.id)"))
    }

    private func repositorySource(at relativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
