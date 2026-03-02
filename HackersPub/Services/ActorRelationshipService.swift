import Foundation
@preconcurrency import Apollo

struct ActorRelationshipState: Equatable {
    let actorId: String
    let handle: String
    let isViewer: Bool
    let viewerFollows: Bool
    let followsViewer: Bool
    let viewerBlocks: Bool

    init(
        actorId: String,
        handle: String,
        isViewer: Bool,
        viewerFollows: Bool,
        followsViewer: Bool,
        viewerBlocks: Bool
    ) {
        self.actorId = actorId
        self.handle = handle
        self.isViewer = isViewer
        self.viewerFollows = viewerFollows
        self.followsViewer = followsViewer
        self.viewerBlocks = viewerBlocks
    }

    init(actor: HackersPub.ActorRelationshipQuery.Data.ActorByHandle) {
        self.init(
            actorId: actor.id,
            handle: actor.handle,
            isViewer: actor.isViewer,
            viewerFollows: actor.viewerFollows,
            followsViewer: actor.followsViewer,
            viewerBlocks: actor.viewerBlocks
        )
    }

    init(actor: HackersPub.ActorByHandleQuery.Data.ActorByHandle) {
        self.init(
            actorId: actor.id,
            handle: actor.handle,
            isViewer: actor.isViewer,
            viewerFollows: actor.viewerFollows,
            followsViewer: actor.followsViewer,
            viewerBlocks: actor.viewerBlocks
        )
    }
}

enum ActorRelationshipAction {
    case follow
    case unfollow
    case block
    case unblock
    case removeFollower
}

enum ActorRelationshipServiceError: LocalizedError {
    case actorNotFound
    case invalidInput(String)
    case notAuthenticated
    case operationFailed

    var errorDescription: String? {
        switch self {
        case .actorNotFound:
            return NSLocalizedString("actorRelation.error.actorNotFound", comment: "Actor not found")
        case .invalidInput(let path):
            return String(
                format: NSLocalizedString("actorRelation.error.invalidInput", comment: "Invalid actor relation input"),
                path
            )
        case .notAuthenticated:
            return NSLocalizedString("actorRelation.error.notAuthenticated", comment: "Not authenticated")
        case .operationFailed:
            return NSLocalizedString("actorRelation.error.operationFailed", comment: "Actor relation action failed")
        }
    }
}

enum ActorRelationshipService {
    static func fetch(
        handle: String,
        cachePolicy: CachePolicy.Query.SingleResponse = .networkFirst
    ) async throws -> ActorRelationshipState? {
        let response = try await apolloClient.fetch(
            query: HackersPub.ActorRelationshipQuery(handle: handle),
            cachePolicy: cachePolicy
        )
        guard let actor = response.data?.actorByHandle else {
            return nil
        }
        return ActorRelationshipState(actor: actor)
    }

    static func perform(action: ActorRelationshipAction, actorId: String) async throws {
        switch action {
        case .follow:
            let response = try await apolloClient.perform(
                mutation: HackersPub.FollowActorMutation(actorId: actorId)
            )
            try validateResult(
                success: response.data?.followActor.asFollowActorPayload != nil,
                invalidInputPath: response.data?.followActor.asInvalidInputError?.inputPath,
                notAuthenticated: response.data?.followActor.asNotAuthenticatedError != nil
            )

        case .unfollow:
            let response = try await apolloClient.perform(
                mutation: HackersPub.UnfollowActorMutation(actorId: actorId)
            )
            try validateResult(
                success: response.data?.unfollowActor.asUnfollowActorPayload != nil,
                invalidInputPath: response.data?.unfollowActor.asInvalidInputError?.inputPath,
                notAuthenticated: response.data?.unfollowActor.asNotAuthenticatedError != nil
            )

        case .block:
            let response = try await apolloClient.perform(
                mutation: HackersPub.BlockActorMutation(actorId: actorId)
            )
            try validateResult(
                success: response.data?.blockActor.asBlockActorPayload != nil,
                invalidInputPath: response.data?.blockActor.asInvalidInputError?.inputPath,
                notAuthenticated: response.data?.blockActor.asNotAuthenticatedError != nil
            )

        case .unblock:
            let response = try await apolloClient.perform(
                mutation: HackersPub.UnblockActorMutation(actorId: actorId)
            )
            try validateResult(
                success: response.data?.unblockActor.asUnblockActorPayload != nil,
                invalidInputPath: response.data?.unblockActor.asInvalidInputError?.inputPath,
                notAuthenticated: response.data?.unblockActor.asNotAuthenticatedError != nil
            )

        case .removeFollower:
            let response = try await apolloClient.perform(
                mutation: HackersPub.RemoveFollowerMutation(actorId: actorId)
            )
            try validateResult(
                success: response.data?.removeFollower.asRemoveFollowerPayload != nil,
                invalidInputPath: response.data?.removeFollower.asInvalidInputError?.inputPath,
                notAuthenticated: response.data?.removeFollower.asNotAuthenticatedError != nil
            )
        }
    }

    private static func validateResult(
        success: Bool,
        invalidInputPath: String?,
        notAuthenticated: Bool
    ) throws {
        if success {
            return
        }
        if let invalidInputPath {
            throw ActorRelationshipServiceError.invalidInput(invalidInputPath)
        }
        if notAuthenticated {
            throw ActorRelationshipServiceError.notAuthenticated
        }
        throw ActorRelationshipServiceError.operationFailed
    }
}

func actorProfileURL(handle: String) -> URL? {
    let normalized = handle.hasPrefix("@") ? handle : "@\(handle)"
    let encoded = normalized.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? normalized
    return URL(string: "https://hackers.pub/\(encoded)")
}
