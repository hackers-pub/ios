enum NewsRequestOutcome: Equatable {
    case success
    case failure(String)
    case cancelled
}

struct NewsRequestLifecycle: Equatable {
    private(set) var currentRequestID = 0
    private(set) var isLoading = false
    private(set) var hasLoadedInitial = false
    private(set) var errorMessage: String?

    var shouldLoadInitial: Bool {
        !hasLoadedInitial && !isLoading
    }

    @discardableResult
    mutating func begin() -> Int {
        currentRequestID += 1
        isLoading = true
        errorMessage = nil
        return currentRequestID
    }

    func isCurrent(_ requestID: Int) -> Bool {
        requestID == currentRequestID
    }

    mutating func finish(requestID: Int, outcome: NewsRequestOutcome) {
        guard isCurrent(requestID) else { return }

        isLoading = false

        switch outcome {
        case .success:
            hasLoadedInitial = true
            errorMessage = nil
        case let .failure(message):
            errorMessage = message
        case .cancelled:
            errorMessage = nil
        }
    }
}

struct NewsAdminLoadState: Equatable {
    private(set) var currentRequestID = 0
    private(set) var hasAttemptedInitialLoad = false
    private(set) var hasLoadedInitial = false
    private(set) var isLoading = false
    private(set) var initialErrorMessage: String?
    private(set) var refreshErrorMessage: String?
    private(set) var actionErrorMessage: String?

    var shouldLoadInitial: Bool {
        !hasLoadedInitial && !isLoading && initialErrorMessage == nil
    }

    var showsInitialFailure: Bool {
        hasAttemptedInitialLoad && !hasLoadedInitial && !isLoading && initialErrorMessage != nil
    }

    @discardableResult
    mutating func begin() -> Int {
        currentRequestID += 1
        isLoading = true

        if hasLoadedInitial {
            refreshErrorMessage = nil
        } else {
            hasAttemptedInitialLoad = true
            initialErrorMessage = nil
        }

        return currentRequestID
    }

    func isCurrent(_ requestID: Int) -> Bool {
        requestID == currentRequestID
    }

    mutating func finish(requestID: Int, outcome: NewsRequestOutcome) {
        guard isCurrent(requestID) else { return }

        isLoading = false

        switch outcome {
        case .success:
            hasLoadedInitial = true
            initialErrorMessage = nil
            refreshErrorMessage = nil
        case let .failure(message):
            if hasLoadedInitial {
                refreshErrorMessage = message
            } else {
                initialErrorMessage = message
            }
        case .cancelled:
            break
        }
    }

    mutating func recordActionFailure(_ message: String) {
        actionErrorMessage = message
    }

    mutating func clearActionError() {
        actionErrorMessage = nil
    }
}

enum NewsModerationFailure: Equatable {
    case graphQLError(String)
    case missingResult
    case notAuthenticated
    case notAuthorized
    case network(String)

    var canRetry: Bool {
        switch self {
        case .graphQLError, .missingResult, .network:
            return true
        case .notAuthenticated, .notAuthorized:
            return false
        }
    }

    var revokesModeratorAffordances: Bool {
        switch self {
        case .notAuthenticated, .notAuthorized:
            return true
        case .graphQLError, .missingResult, .network:
            return false
        }
    }
}

struct NewsModerationPresentationState: Equatable {
    private(set) var isModerator: Bool
    private(set) var error: NewsModerationFailure?

    init(isModerator: Bool = false) {
        self.isModerator = isModerator
    }

    mutating func updateModeratorStatus(_ isModerator: Bool) {
        self.isModerator = isModerator
    }

    mutating func record(_ failure: NewsModerationFailure) {
        error = failure
        if failure.revokesModeratorAffordances {
            isModerator = false
        }
    }

    mutating func clearError() {
        error = nil
    }
}
