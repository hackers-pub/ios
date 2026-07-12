import Foundation

@MainActor
protocol PasskeyAuthorizing {
    func authenticate(options: PasskeyAuthenticationOptions) async throws -> HackersPub.JSON
    func register(options: PasskeyRegistrationOptions) async throws -> HackersPub.JSON
}

enum AuthLocalePolicy {
    static func effectiveLocale(requested: String?, currentLocale: Locale = .current) -> String {
        if let requested = requested?.trimmingCharacters(in: .whitespacesAndNewlines), !requested.isEmpty {
            return requested
        }

        let identifier = currentLocale.language.maximalIdentifier
        return identifier.isEmpty ? "en" : identifier
    }
}

enum PasskeyListLoadState: Equatable {
    case idle
    case loading
    case failed

    mutating func beginLoading() {
        self = .loading
    }

    mutating func finishLoading() {
        self = .idle
    }

    mutating func fail() {
        self = .failed
    }
}

@MainActor
final class PasskeyTaskOwner {
    private var task: Task<Void, Never>?

    func start(_ operation: @escaping @MainActor () async -> Void) {
        cancel()
        task = Task { @MainActor in
            guard !Task.isCancelled else { return }
            await operation()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
