import Foundation
@testable import HackersPub
import Testing

@MainActor
struct ActorProfileRelationshipStateTests {
    @Test func confirmedTypedReceiptUpdatesOnlyTheRelationshipOverlay() {
        var coordinator = ProfileRelationshipActionCoordinator()
        let initial = relationshipState()
        let request = coordinator.begin(action: .follow, actorID: initial.actorId)

        let updated = coordinator.apply(
            ActorRelationshipMutationReceipt(action: .follow, actorID: initial.actorId),
            for: request,
            to: initial
        )

        #expect(updated?.viewerFollows == true)
        #expect(updated?.viewerBlocks == false)
        #expect(updated?.followsViewer == initial.followsViewer)
        #expect(!coordinator.isPerformingAction)
    }

    @Test func staleFollowCannotOverwriteANewerUnfollow() {
        var coordinator = ProfileRelationshipActionCoordinator()
        let initial = relationshipState(viewerFollows: false)
        let follow = coordinator.begin(action: .follow, actorID: initial.actorId)
        let unfollow = coordinator.begin(action: .unfollow, actorID: initial.actorId)

        let staleUpdate = coordinator.apply(
            ActorRelationshipMutationReceipt(action: .follow, actorID: initial.actorId),
            for: follow,
            to: initial
        )
        #expect(staleUpdate == nil)
        #expect(coordinator.isPerformingAction)

        let currentUpdate = coordinator.apply(
            ActorRelationshipMutationReceipt(action: .unfollow, actorID: initial.actorId),
            for: unfollow,
            to: initial
        )
        #expect(currentUpdate?.viewerFollows == false)
        #expect(!coordinator.isPerformingAction)
    }

    @Test func newerBlockWinsOverAnOlderFollowAndClearsTheConflictingFollowState() {
        var coordinator = ProfileRelationshipActionCoordinator()
        let initial = relationshipState(viewerFollows: false, viewerBlocks: false)
        let follow = coordinator.begin(action: .follow, actorID: initial.actorId)
        let block = coordinator.begin(action: .block, actorID: initial.actorId)

        #expect(
            coordinator.apply(
                ActorRelationshipMutationReceipt(action: .follow, actorID: initial.actorId),
                for: follow,
                to: initial
            ) == nil
        )

        let updated = coordinator.apply(
            ActorRelationshipMutationReceipt(action: .block, actorID: initial.actorId),
            for: block,
            to: initial
        )
        #expect(updated?.viewerBlocks == true)
        #expect(updated?.viewerFollows == false)
    }

    @Test func failuresAndCancellationDoNotMutateTheConfirmedRelationshipState() {
        var coordinator = ProfileRelationshipActionCoordinator()
        let initial = relationshipState()
        let request = coordinator.begin(action: .follow, actorID: initial.actorId)

        let didFinishFailure = coordinator.finishFailure(for: request)
        #expect(didFinishFailure)
        #expect(!coordinator.isPerformingAction)
        #expect(initial.viewerFollows == false)

        let cancelled = coordinator.begin(action: .block, actorID: initial.actorId)
        let didFinishCancellation = coordinator.finishFailure(for: cancelled)
        #expect(didFinishCancellation)
        #expect(initial.viewerBlocks == false)
    }

    @Test func actorIdentityMismatchesNeverApplyAnOtherwiseCurrentReceipt() {
        var coordinator = ProfileRelationshipActionCoordinator()
        let initial = relationshipState(actorID: "actor-a")
        let request = coordinator.begin(action: .follow, actorID: initial.actorId)

        let updated = coordinator.apply(
            ActorRelationshipMutationReceipt(action: .follow, actorID: "actor-b"),
            for: request,
            to: initial
        )

        #expect(updated == nil)
        #expect(coordinator.isPerformingAction)
    }

    @Test func failedRelationshipRetryCannotRenderOrExecuteAfterActorSwitches() {
        let retry = ActorProfileRelationshipRetry(
            action: .follow,
            actorID: "actor-a",
            generation: 0
        )

        #expect(retry.actionIfCurrent(actorID: "actor-a", generation: 0) == .follow)

        // A -> B: A's error must not render or target B.
        #expect(retry.actionIfCurrent(actorID: "actor-b", generation: 1) == nil)

        // A -> B -> A: identity alone is insufficient; the old retry stays stale.
        #expect(retry.actionIfCurrent(actorID: "actor-a", generation: 2) == nil)
    }

    @Test func profileViewClearsAndGuardsRelationshipRetriesAtActorBoundaries() throws {
        let source = try actorProfileViewSource()
        let reset = try #require(source.block(after: "private func resetTabs"))
        let action = try #require(source.block(after: "private func performRelationshipAction"))

        #expect(reset.contains("relationshipRetryGeneration &+= 1"))
        #expect(reset.contains("relationshipActionTask?.cancel()"))
        #expect(reset.contains("failedRelationshipRetry = nil"))
        #expect(reset.contains("relationshipActionErrorMessage = nil"))
        #expect(action.contains("ActorProfileRelationshipRetry"))
        #expect(action.contains("retryGeneration == relationshipRetryGeneration"))
    }

    @Test func profileViewUsesTheConfirmedReceiptCoordinatorInsteadOfRefetchingPostsForAnAction() throws {
        let source = try actorProfileViewSource()
        let action = try #require(source.block(after: "private func performRelationshipAction"))

        #expect(action.contains("relationshipActionCoordinator.begin"))
        #expect(action.contains("ActorRelationshipService.perform"))
        #expect(action.contains("relationshipActionCoordinator.apply"))
        #expect(!action.contains("fetchProfile(cachePolicy:"))
        #expect(source.contains("failedRelationshipRetry"))
        #expect(source.contains("NSLocalizedString(\"common.retry\""))
    }

    @Test func relationshipServiceValidatesGraphQLErrorsAndReturnsTypedReceipts() throws {
        let source = try actorRelationshipServiceSource()

        #expect(source.contains("ActorRelationshipMutationReceipt"))
        #expect(source.contains("response.errors?.first"))
        #expect(source.contains("result?.asFollowActorPayload?.followee.id"))
        #expect(source.contains("result?.asBlockActorPayload?.blockee.id"))
        #expect(source.contains("result?.asRemoveFollowerPayload?.follower.id"))
        #expect(source.contains("payloadActorID == expectedActorID"))
    }

    private func relationshipState(
        actorID: String = "actor-a",
        viewerFollows: Bool = false,
        followsViewer: Bool = true,
        viewerBlocks: Bool = false
    ) -> ActorRelationshipState {
        ActorRelationshipState(
            actorId: actorID,
            handle: "@actor@example.com",
            isViewer: false,
            viewerFollows: viewerFollows,
            followsViewer: followsViewer,
            viewerBlocks: viewerBlocks
        )
    }

    private func actorProfileViewSource() throws -> String {
        try repositorySource(at: "HackersPub/Views/Profile/ActorProfileView.swift")
    }

    private func actorRelationshipServiceSource() throws -> String {
        try repositorySource(at: "HackersPub/Services/ActorRelationshipService.swift")
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

private extension String {
    func block(after marker: String) -> String? {
        guard let markerRange = range(of: marker) else {
            return nil
        }
        guard let openingBrace = self[markerRange.upperBound...].firstIndex(of: "{") else {
            return nil
        }

        var depth = 0
        var index = openingBrace
        while index < endIndex {
            switch self[index] {
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(self[openingBrace ... index])
                }
            default:
                break
            }
            index = self.index(after: index)
        }
        return nil
    }
}
