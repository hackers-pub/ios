import Foundation

enum TimelineResponseDisposition: Equatable {
    case usable
    case usableWithWarning(String)
    case failure(String)
}

enum TimelineResponsePolicy {
    static func disposition(
        hasConnection: Bool,
        incomingCount: Int,
        hasExistingContent: Bool,
        graphQLErrorMessages: [String],
        fallbackMessage: String
    ) -> TimelineResponseDisposition {
        let message = graphQLErrorMessages
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? fallbackMessage

        guard !graphQLErrorMessages.isEmpty else {
            return hasConnection ? .usable : .failure(fallbackMessage)
        }

        let hasUsableContent = incomingCount > 0 || hasExistingContent
        guard hasConnection, hasUsableContent else {
            return .failure(message)
        }

        return .usableWithWarning(message)
    }
}
