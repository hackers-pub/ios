@preconcurrency import Apollo
import Foundation

enum RelayIdentifier {
    static func encoded(type: String, rawID: String) -> String {
        let canonicalID = UUID(uuidString: rawID)?.uuidString.lowercased() ?? rawID
        return Foundation.Data("\(type):\(canonicalID)".utf8).base64EncodedString()
    }
}

enum DeepLinkPostResolver {
    static func resolvePostID(for url: String) async throws -> String? {
        try await resolvePostID(
            for: url,
            fetchPostByURL: { url in
                try await fetchPostID(for: url)
            }
        )
    }

    static func resolvePostID(
        for url: String,
        fetchPostByURL: (String) async throws -> String?
    ) async throws -> String? {
        if let postID = try await fetchPostByURL(url) {
            return postID
        }

        if let postID = try await validatedNoteID(from: url) {
            return postID
        }

        return try await articleID(from: url)
    }

    private static func fetchPostID(for url: String) async throws -> String? {
        let response = try await apolloClient.fetch(
            query: HackersPub.PostByUrlQuery(url: url),
            cachePolicy: .networkOnly
        )
        return response.data?.postByUrl?.id
    }

    private static func validatedNoteID(from urlString: String) async throws -> String? {
        guard
            let url = URL(string: urlString),
            HackersPubURLRouter.isHackersPubWebURL(url),
            let targetURL = DeepLinkURLCanonicalizer.normalizedURLString(urlString)
        else { return nil }

        let segments = DeepLinkURLPath.decodedSegments(from: url)
        guard segments.count >= 2 else { return nil }

        let handle = handle(from: segments[0])
        let noteID: String
        if isUUID(segments[1]) {
            noteID = RelayIdentifier.encoded(type: "Note", rawID: segments[1])
        } else if segments.count >= 3, segments[1].lowercased() == "polls", isUUID(segments[2]) {
            noteID = RelayIdentifier.encoded(type: "Note", rawID: segments[2])
        } else {
            return nil
        }

        let response = try await apolloClient.fetch(
            query: HackersPub.PostDetailQuery(id: noteID, repliesAfter: nil),
            cachePolicy: .networkOnly
        )
        guard let post = response.data?.node?.asPost else { return nil }
        var acceptableURLs: Set<String> = [targetURL]
        if let redirectedURL = try await redirectedURLString(from: url) {
            acceptableURLs.insert(redirectedURL)
        }
        guard
            let postURL = post.url,
            let normalizedPostURL = DeepLinkURLCanonicalizer.normalizedURLString(postURL),
            acceptableURLs.contains(normalizedPostURL)
        else { return nil }
        if let handle {
            guard normalizedHandle(post.actor.handle) == normalizedHandle(handle) else { return nil }
        }

        return post.id
    }

    private static func articleID(from urlString: String) async throws -> String? {
        guard
            let url = URL(string: urlString),
            HackersPubURLRouter.isHackersPubWebURL(url),
            let handle = articleHandle(from: url),
            let targetURL = DeepLinkURLCanonicalizer.normalizedURLString(urlString)
        else { return nil }

        var after: String?
        for _ in 0 ..< 10 {
            let cursor: GraphQLNullable<String> = after.map { .some($0) } ?? nil
            let response = try await apolloClient.fetch(
                query: HackersPub.ActorArticlesQuery(
                    handle: handle,
                    after: cursor,
                    before: nil,
                    first: 20,
                    last: nil
                ),
                cachePolicy: .networkOnly
            )
            guard let articles = response.data?.actorByHandle?.articles else { return nil }

            if let article = articles.edges.first(where: { edge in
                guard let articleURL = edge.node.url else { return false }
                return DeepLinkURLCanonicalizer.normalizedURLString(articleURL) == targetURL
            }) {
                return article.node.id
            }

            guard articles.pageInfo.hasNextPage, let endCursor = articles.pageInfo.endCursor else {
                return nil
            }
            after = endCursor
        }

        return nil
    }

    private static func articleHandle(from url: URL) -> String? {
        let segments = DeepLinkURLPath.decodedSegments(from: url)
        guard segments.count >= 3, segments[0].hasPrefix("@"), isYear(segments[1]) else {
            return nil
        }
        return handle(from: segments[0])
    }

    private static func isUUID(_ value: String) -> Bool {
        value.range(
            of: #"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func isYear(_ value: String) -> Bool {
        value.range(of: #"^\d{4}$"#, options: .regularExpression) != nil
    }

    private static func handle(from segment: String) -> String? {
        guard segment.hasPrefix("@") else { return nil }
        let handle = String(segment.dropFirst())
        guard !handle.isEmpty else { return nil }
        return handle.contains("@") ? handle : "\(handle)@hackers.pub"
    }

    private static func normalizedHandle(_ value: String) -> String {
        let handle = value.hasPrefix("@") ? String(value.dropFirst()) : value
        return handle.lowercased()
    }

    private static func redirectedURLString(from url: URL) async throws -> String? {
        guard let redirectedURL = try await RedirectURLProbe().redirectedURL(from: url) else {
            return nil
        }
        return DeepLinkURLCanonicalizer.normalizedURLString(redirectedURL.absoluteString)
    }
}
