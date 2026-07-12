@preconcurrency import Apollo
import Foundation

// swiftlint:disable file_length

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

    func applying(_ action: ActorRelationshipAction) -> ActorRelationshipState {
        switch action {
        case .follow:
            ActorRelationshipState(
                actorId: actorId,
                handle: handle,
                isViewer: isViewer,
                viewerFollows: true,
                followsViewer: followsViewer,
                viewerBlocks: false
            )
        case .unfollow:
            ActorRelationshipState(
                actorId: actorId,
                handle: handle,
                isViewer: isViewer,
                viewerFollows: false,
                followsViewer: followsViewer,
                viewerBlocks: viewerBlocks
            )
        case .block:
            ActorRelationshipState(
                actorId: actorId,
                handle: handle,
                isViewer: isViewer,
                viewerFollows: false,
                followsViewer: followsViewer,
                viewerBlocks: true
            )
        case .unblock:
            ActorRelationshipState(
                actorId: actorId,
                handle: handle,
                isViewer: isViewer,
                viewerFollows: viewerFollows,
                followsViewer: followsViewer,
                viewerBlocks: false
            )
        case .removeFollower:
            ActorRelationshipState(
                actorId: actorId,
                handle: handle,
                isViewer: isViewer,
                viewerFollows: viewerFollows,
                followsViewer: false,
                viewerBlocks: viewerBlocks
            )
        }
    }
}

enum ActorRelationshipAction: Equatable, Sendable {
    case follow
    case unfollow
    case block
    case unblock
    case removeFollower
}

enum ActorRelationshipFetchOutcome: Equatable {
    case found
    case notFound
    case queryFailed
}

enum ActorRelationshipFetchPolicy {
    static func outcome(graphQLErrorsPresent: Bool, actorPresent: Bool) -> ActorRelationshipFetchOutcome {
        if actorPresent {
            return .found
        }
        return graphQLErrorsPresent ? .queryFailed : .notFound
    }
}

struct ActorRelationshipRequestToken: Equatable {
    let handle: String
    fileprivate let generation: Int
}

final class ActorRelationshipStateUpdateGate {
    private var generation = 0

    func begin(handle: String) -> ActorRelationshipRequestToken {
        generation += 1
        return ActorRelationshipRequestToken(handle: handle, generation: generation)
    }

    func invalidate() {
        generation += 1
    }

    func allows(_ request: ActorRelationshipRequestToken, currentHandle: String?) -> Bool {
        request.generation == generation && request.handle == currentHandle
    }
}

struct ActorRelationshipMutationReceipt: Equatable, Sendable {
    let action: ActorRelationshipAction
    let actorID: String
}

struct ActorProfileRelationshipActionRequest: Equatable, Sendable {
    let generation: UInt64
    let action: ActorRelationshipAction
    let actorID: String
}

struct ActorProfileRelationshipRetry: Equatable, Sendable {
    let action: ActorRelationshipAction
    let actorID: String
    let generation: UInt64

    func actionIfCurrent(actorID: String, generation: UInt64) -> ActorRelationshipAction? {
        guard self.actorID == actorID, self.generation == generation else {
            return nil
        }
        return action
    }
}

@MainActor
struct ProfileRelationshipActionCoordinator {
    private var nextGeneration: UInt64 = 0
    private(set) var activeRequest: ActorProfileRelationshipActionRequest?

    var isPerformingAction: Bool {
        activeRequest != nil
    }

    mutating func begin(
        action: ActorRelationshipAction,
        actorID: String
    ) -> ActorProfileRelationshipActionRequest {
        nextGeneration &+= 1
        let request = ActorProfileRelationshipActionRequest(
            generation: nextGeneration,
            action: action,
            actorID: actorID
        )
        activeRequest = request
        return request
    }

    mutating func apply(
        _ receipt: ActorRelationshipMutationReceipt,
        for request: ActorProfileRelationshipActionRequest,
        to state: ActorRelationshipState
    ) -> ActorRelationshipState? {
        guard activeRequest == request,
              receipt.action == request.action,
              receipt.actorID == request.actorID,
              state.actorId == request.actorID
        else {
            return nil
        }

        activeRequest = nil
        return state.applying(receipt.action)
    }

    mutating func finishFailure(for request: ActorProfileRelationshipActionRequest) -> Bool {
        guard activeRequest == request else {
            return false
        }
        activeRequest = nil
        return true
    }

    mutating func invalidate() {
        nextGeneration &+= 1
        activeRequest = nil
    }
}

enum ActorRelationshipServiceError: LocalizedError {
    case actorNotFound
    case queryFailed
    case invalidInput(String)
    case notAuthenticated
    case operationFailed

    var errorDescription: String? {
        switch self {
        case .actorNotFound:
            NSLocalizedString("actorRelation.error.actorNotFound", comment: "Actor not found")
        case .queryFailed:
            NSLocalizedString("actorRelation.error.queryFailed", comment: "Actor relationship query failed")
        case let .invalidInput(path):
            String(
                format: NSLocalizedString("actorRelation.error.invalidInput", comment: "Invalid actor relation input"),
                path
            )
        case .notAuthenticated:
            NSLocalizedString("actorRelation.error.notAuthenticated", comment: "Not authenticated")
        case .operationFailed:
            NSLocalizedString("actorRelation.error.operationFailed", comment: "Actor relation action failed")
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
        return try resolveFetchResult(
            graphQLErrorsPresent: response.errors?.isEmpty == false,
            relationship: response.data?.actorByHandle.map(ActorRelationshipState.init)
        )
    }

    static func resolveFetchResult(
        graphQLErrorsPresent: Bool,
        relationship: ActorRelationshipState?
    ) throws -> ActorRelationshipState? {
        switch ActorRelationshipFetchPolicy.outcome(
            graphQLErrorsPresent: graphQLErrorsPresent,
            actorPresent: relationship != nil
        ) {
        case .found:
            return relationship
        case .notFound:
            return nil
        case .queryFailed:
            throw ActorRelationshipServiceError.queryFailed
        }
    }

    @discardableResult
    static func perform(
        action: ActorRelationshipAction,
        actorId: String
    ) async throws -> ActorRelationshipMutationReceipt {
        switch action {
        case .follow:
            try await follow(actorID: actorId)

        case .unfollow:
            try await unfollow(actorID: actorId)

        case .block:
            try await block(actorID: actorId)

        case .unblock:
            try await unblock(actorID: actorId)

        case .removeFollower:
            try await removeFollower(actorID: actorId)
        }
    }

    private static func follow(actorID: String) async throws -> ActorRelationshipMutationReceipt {
        let response = try await apolloClient.perform(
            mutation: HackersPub.FollowActorMutation(actorId: actorID)
        )
        let result = response.data?.followActor
        let confirmedActorID = try validatedActorID(
            hasGraphQLErrors: response.errors?.first != nil,
            invalidInputPath: result?.asInvalidInputError?.inputPath,
            isNotAuthenticated: result?.asNotAuthenticatedError != nil,
            payloadActorID: result?.asFollowActorPayload?.followee.id,
            expectedActorID: actorID
        )
        return ActorRelationshipMutationReceipt(action: .follow, actorID: confirmedActorID)
    }

    private static func unfollow(actorID: String) async throws -> ActorRelationshipMutationReceipt {
        let response = try await apolloClient.perform(
            mutation: HackersPub.UnfollowActorMutation(actorId: actorID)
        )
        let result = response.data?.unfollowActor
        let confirmedActorID = try validatedActorID(
            hasGraphQLErrors: response.errors?.first != nil,
            invalidInputPath: result?.asInvalidInputError?.inputPath,
            isNotAuthenticated: result?.asNotAuthenticatedError != nil,
            payloadActorID: result?.asUnfollowActorPayload?.followee.id,
            expectedActorID: actorID
        )
        return ActorRelationshipMutationReceipt(action: .unfollow, actorID: confirmedActorID)
    }

    private static func block(actorID: String) async throws -> ActorRelationshipMutationReceipt {
        let response = try await apolloClient.perform(
            mutation: HackersPub.BlockActorMutation(actorId: actorID)
        )
        let result = response.data?.blockActor
        let confirmedActorID = try validatedActorID(
            hasGraphQLErrors: response.errors?.first != nil,
            invalidInputPath: result?.asInvalidInputError?.inputPath,
            isNotAuthenticated: result?.asNotAuthenticatedError != nil,
            payloadActorID: result?.asBlockActorPayload?.blockee.id,
            expectedActorID: actorID
        )
        return ActorRelationshipMutationReceipt(action: .block, actorID: confirmedActorID)
    }

    private static func unblock(actorID: String) async throws -> ActorRelationshipMutationReceipt {
        let response = try await apolloClient.perform(
            mutation: HackersPub.UnblockActorMutation(actorId: actorID)
        )
        let result = response.data?.unblockActor
        let confirmedActorID = try validatedActorID(
            hasGraphQLErrors: response.errors?.first != nil,
            invalidInputPath: result?.asInvalidInputError?.inputPath,
            isNotAuthenticated: result?.asNotAuthenticatedError != nil,
            payloadActorID: result?.asUnblockActorPayload?.blockee.id,
            expectedActorID: actorID
        )
        return ActorRelationshipMutationReceipt(action: .unblock, actorID: confirmedActorID)
    }

    private static func removeFollower(actorID: String) async throws -> ActorRelationshipMutationReceipt {
        let response = try await apolloClient.perform(
            mutation: HackersPub.RemoveFollowerMutation(actorId: actorID)
        )
        let result = response.data?.removeFollower
        let confirmedActorID = try validatedActorID(
            hasGraphQLErrors: response.errors?.first != nil,
            invalidInputPath: result?.asInvalidInputError?.inputPath,
            isNotAuthenticated: result?.asNotAuthenticatedError != nil,
            payloadActorID: result?.asRemoveFollowerPayload?.follower.id,
            expectedActorID: actorID
        )
        return ActorRelationshipMutationReceipt(action: .removeFollower, actorID: confirmedActorID)
    }

    private static func validatedActorID(
        hasGraphQLErrors: Bool,
        invalidInputPath: String?,
        isNotAuthenticated: Bool,
        payloadActorID: String?,
        expectedActorID: String
    ) throws -> String {
        guard !hasGraphQLErrors else {
            throw ActorRelationshipServiceError.operationFailed
        }
        if let invalidInputPath {
            throw ActorRelationshipServiceError.invalidInput(invalidInputPath)
        }
        guard !isNotAuthenticated else {
            throw ActorRelationshipServiceError.notAuthenticated
        }
        guard let payloadActorID, payloadActorID == expectedActorID else {
            throw ActorRelationshipServiceError.operationFailed
        }
        return payloadActorID
    }
}

func actorProfileURL(handle: String) -> URL? {
    let normalized = handle.hasPrefix("@") ? handle : "@\(handle)"
    let encoded = normalized.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? normalized
    return URL(string: "https://hackers.pub/\(encoded)")
}
