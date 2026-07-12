import Foundation

struct TimelineRefreshWarning: Equatable, Sendable {
    enum Reason: Equatable, Sendable {
        case graphQLPartialResponse
        case laterPageFailure
        case pageLimitReached
        case uniqueRowLimitReached
        case noProgress
    }

    let reason: Reason
    let message: String
    let debugMessage: String?

    static var localizedMessage: String {
        NSLocalizedString(
            "timeline.refresh.partialWarning",
            comment: "Warning shown when only part of a timeline refresh succeeds"
        )
    }

    static func graphQLPartialResponse(
        debugMessage: String,
        message: String = localizedMessage
    ) -> TimelineRefreshWarning {
        TimelineRefreshWarning(
            reason: .graphQLPartialResponse,
            message: message,
            debugMessage: debugMessage
        )
    }

    static func graphQLPartialResponse(
        debugMessages: [String],
        message: String = localizedMessage
    ) -> TimelineRefreshWarning? {
        guard let debugMessage = debugMessages
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty })
        else {
            return nil
        }

        return graphQLPartialResponse(debugMessage: debugMessage, message: message)
    }
}

struct TimelineRefreshPage<Edge> {
    let edges: [Edge]
    let pageInfo: TimelinePageInfo
    let warning: TimelineRefreshWarning?
}

enum TimelineRefreshCompleteness: Equatable, Sendable {
    case authoritative
    case partial(TimelineRefreshWarning)
}

struct TimelineRefreshLimits: Equatable, Sendable {
    let maxPages: Int
    let maxUniqueRows: Int
    let maxConsecutiveNoProgressPages: Int

    static let production = TimelineRefreshLimits(
        maxPages: 8,
        maxUniqueRows: 160,
        maxConsecutiveNoProgressPages: 2
    )

    init(
        maxPages: Int,
        maxUniqueRows: Int,
        maxConsecutiveNoProgressPages: Int
    ) {
        precondition(maxPages > 0)
        precondition(maxUniqueRows > 0)
        precondition(maxConsecutiveNoProgressPages > 0)

        self.maxPages = maxPages
        self.maxUniqueRows = maxUniqueRows
        self.maxConsecutiveNoProgressPages = maxConsecutiveNoProgressPages
    }
}

struct TimelineRefreshSnapshot<Edge> {
    let edges: [Edge]
    let pageInfo: TimelinePageInfo
    let completeness: TimelineRefreshCompleteness

    var warning: TimelineRefreshWarning? {
        guard case let .partial(warning) = completeness else { return nil }
        return warning
    }

    var warningMessage: String? {
        warning?.message
    }

    var isAuthoritative: Bool {
        completeness == .authoritative
    }
}

struct TimelineRefreshError: Equatable, LocalizedError {
    let userMessage: String
    let debugMessage: String?

    var errorDescription: String? {
        userMessage
    }
}

@MainActor
func timelineRefreshResponse<Value>(
    userMessage: String,
    operation: () async throws -> Value
) async throws -> Value {
    do {
        return try await operation()
    } catch {
        if error is CancellationError || Task.isCancelled {
            throw error
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            throw error
        }
        throw TimelineRefreshError(
            userMessage: userMessage,
            debugMessage: error.localizedDescription
        )
    }
}
