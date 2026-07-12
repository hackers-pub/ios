@preconcurrency import Apollo

struct ReplyContext: Equatable {
    let postID: String
    let visibility: GraphQLEnum<HackersPub.PostVisibility>
    let authorHandle: String
    let mentionHandles: [String]
}

struct ReplyContextPage {
    let postID: String
    let visibility: GraphQLEnum<HackersPub.PostVisibility>
    let authorHandle: String
    let mentionHandles: [String]
    let hasNextPage: Bool
    let endCursor: String?
}

enum ReplyContextLoadOutcome: Equatable {
    case loaded(ReplyContext)
    case failed(String)
    case ignored
}

func isSupportedCreateNoteVisibility(
    _ visibility: GraphQLEnum<HackersPub.PostVisibility>
) -> Bool {
    switch visibility {
    case .case(.public), .case(.unlisted), .case(.followers), .case(.direct):
        return true
    case .case(.none), .unknown:
        return false
    }
}
