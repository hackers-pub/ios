import Foundation

struct ActorProfileDestinationContext: Equatable, Hashable, Sendable {
    let handle: String
    let accountID: String?

    func matches(handle returnedHandle: String) -> Bool {
        Self.canonicalHandle(handle) == Self.canonicalHandle(returnedHandle)
    }

    private static func canonicalHandle(_ handle: String) -> String {
        handle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .drop(while: { $0 == "@" })
            .lowercased()
    }
}

struct ActorProfileDestinationRequest: Equatable, Sendable {
    let context: ActorProfileDestinationContext
    let generation: UInt64
}

enum ActorProfileDestinationFailure: Equatable {
    case notFound
    case graphQL
    case transport

    var localizationKey: String {
        switch self {
        case .notFound:
            return "profile.destination.error.notFound"
        case .graphQL, .transport:
            return "profile.destination.error.unavailable"
        }
    }

    var localizedMessage: String {
        NSLocalizedString(localizationKey, comment: "Profile destination load error")
    }
}

enum ActorProfileDestinationPresentation: Equatable {
    case idle
    case loading
    case failed(ActorProfileDestinationFailure)
    case loaded
}

struct ActorProfileDestinationLoadCoordinator {
    private(set) var context: ActorProfileDestinationContext?
    private var nextGeneration: UInt64 = 0
    private var activeRequest: ActorProfileDestinationRequest?

    mutating func begin(
        context: ActorProfileDestinationContext
    ) -> ActorProfileDestinationRequest {
        nextGeneration &+= 1
        let request = ActorProfileDestinationRequest(
            context: context,
            generation: nextGeneration
        )
        self.context = context
        activeRequest = request
        return request
    }

    func isCurrent(_ request: ActorProfileDestinationRequest) -> Bool {
        context == request.context && activeRequest == request
    }

    @discardableResult
    mutating func finish(_ request: ActorProfileDestinationRequest) -> Bool {
        guard isCurrent(request) else {
            return false
        }
        activeRequest = nil
        return true
    }
}
