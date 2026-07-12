@preconcurrency import Apollo
import Foundation

struct CreateNoteDispatchRequest {
    let content: String
    let language: String
    let visibility: GraphQLEnum<HackersPub.PostVisibility>
    let media: [HackersPub.CreateNoteMediumInput]
    let replyTargetID: String?
    let quotedPostID: String?

    var mutation: HackersPub.CreateNoteMutation {
        HackersPub.CreateNoteMutation(
            content: content,
            language: language,
            visibility: visibility,
            media: media.isEmpty ? [] : .some(media),
            replyTargetId: replyTargetID.map(GraphQLNullable.some) ?? .none,
            quotedPostId: quotedPostID.map(GraphQLNullable.some) ?? .none
        )
    }
}

enum CreateNoteDispatchOutcome: Equatable {
    case created(id: String)
    case invalidInput(path: String)
    case notAuthenticated
    case failed
}

enum ComposeNoteDispatchError: LocalizedError, Equatable {
    case unsupportedVisibility

    var errorDescription: String? {
        NSLocalizedString(
            "compose.reply.contextUnavailable",
            comment: "Reply context unavailable"
        )
    }
}

typealias CreateNoteMutationPerformer = @MainActor (
    HackersPub.CreateNoteMutation
) async throws -> CreateNoteDispatchOutcome

final class ComposeNoteDispatcher {
    static let live = ComposeNoteDispatcher { mutation in
        let response = try await apolloClient.perform(mutation: mutation)

        if let payload = response.data?.createNote.asCreateNotePayload {
            return .created(id: payload.note.id)
        }
        if let invalidInput = response.data?.createNote.asInvalidInputError {
            return .invalidInput(path: invalidInput.inputPath)
        }
        if response.data?.createNote.asNotAuthenticatedError != nil {
            return .notAuthenticated
        }
        return .failed
    }

    private let perform: CreateNoteMutationPerformer

    init(perform: @escaping CreateNoteMutationPerformer) {
        self.perform = perform
    }

    @MainActor
    func submit(
        _ request: CreateNoteDispatchRequest
    ) async throws -> CreateNoteDispatchOutcome {
        guard isSupportedCreateNoteVisibility(request.visibility) else {
            throw ComposeNoteDispatchError.unsupportedVisibility
        }
        return try await perform(request.mutation)
    }
}

enum ComposeInputErrorMapper {
    static func localizationKey(for inputPath: String) -> String {
        let normalizedPath = inputPath.lowercased()

        if normalizedPath.contains("content") {
            return "compose.error.invalidContent"
        }
        if normalizedPath.contains("language") {
            return "compose.error.invalidLanguage"
        }
        if normalizedPath.contains("visibility") {
            return "compose.error.invalidVisibility"
        }
        if normalizedPath.contains("media") {
            return "compose.error.invalidMedia"
        }

        return "compose.error.invalidInput"
    }

    static func message(for inputPath: String) -> String {
        NSLocalizedString(
            localizationKey(for: inputPath),
            comment: "Create note invalid input error"
        )
    }
}
