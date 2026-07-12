import Foundation

struct PostReactionInfoRequest: Equatable {
    let targetPostID: String
    let targetGeneration: Int
    let stateRevision: Int
    let requestID: Int
}

struct PostReactionMutationAttempt: Equatable {
    let targetPostID: String
    let targetGeneration: Int
    let mutationID: Int
}

enum PostReactionMutationOutcome: Equatable {
    case success
    case cancelled
    case failure
}

enum PostReactionMutationCompletion: Equatable {
    case ignore
    case synchronize
    case rollbackWithoutError
    case rollbackWithError
}

struct PostReactionRequestCoordinator: Equatable {
    private(set) var targetPostID: String
    private var targetGeneration = 0
    private var stateRevision = 0
    private var nextRequestID = 0
    private var latestMutationID = 0

    init(targetPostID: String) {
        self.targetPostID = targetPostID
    }

    mutating func setTargetPostID(_ postID: String) {
        guard postID != targetPostID else { return }
        targetPostID = postID
        targetGeneration += 1
        stateRevision += 1
    }

    mutating func beginInfoLoad() -> PostReactionInfoRequest? {
        nextRequestID += 1
        return PostReactionInfoRequest(
            targetPostID: targetPostID,
            targetGeneration: targetGeneration,
            stateRevision: stateRevision,
            requestID: nextRequestID
        )
    }

    mutating func beginMutation() -> PostReactionMutationAttempt? {
        latestMutationID += 1
        stateRevision += 1
        return PostReactionMutationAttempt(
            targetPostID: targetPostID,
            targetGeneration: targetGeneration,
            mutationID: latestMutationID
        )
    }

    func shouldApply(_ request: PostReactionInfoRequest) -> Bool {
        request.targetPostID == targetPostID
            && request.targetGeneration == targetGeneration
            && request.stateRevision == stateRevision
    }

    mutating func finish(
        _ attempt: PostReactionMutationAttempt,
        outcome: PostReactionMutationOutcome
    ) -> PostReactionMutationCompletion {
        guard attempt.targetPostID == targetPostID,
              attempt.targetGeneration == targetGeneration,
              attempt.mutationID == latestMutationID
        else {
            return .ignore
        }

        switch outcome {
        case .success:
            return .synchronize
        case .cancelled:
            stateRevision += 1
            return .rollbackWithoutError
        case .failure:
            stateRevision += 1
            return .rollbackWithError
        }
    }
}
