import Foundation
@preconcurrency import Apollo

enum HackersPubDeepLinkRoute: Equatable {
    case profile(handle: String)
    case postURL(String)
    case signInVerification(token: String, code: String)
    case tagSearch(String)
}

enum HackersPubURLRouter {
    private static let host = "hackers.pub"
    private static let uuidPattern = #"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"#
    private static let yearPattern = #"^\d{4}$"#

    static func resolve(_ url: URL) -> HackersPubDeepLinkRoute? {
        if url.scheme == "hackerspub", url.host == "verify" {
            guard
                let token = queryValue("token", in: url),
                let code = queryValue("code", in: url)
            else { return nil }
            return .signInVerification(token: token, code: code)
        }

        guard
            let scheme = url.scheme?.lowercased(),
            scheme == "https" || scheme == "http",
            url.host?.lowercased() == host
        else { return nil }

        let segments = pathSegments(from: url)

        if segments.count == 2, segments[0] == "tags", !segments[1].isEmpty {
            return .tagSearch(segments[1])
        }

        if segments.count >= 3, segments[0] == "sign", segments[1] == "in" {
            guard let code = queryValue("code", in: url) else { return nil }
            return .signInVerification(token: segments[2], code: code)
        }

        if segments.count == 1, segments[0] == "verify" {
            guard
                let token = queryValue("token", in: url),
                let code = queryValue("code", in: url)
            else { return nil }
            return .signInVerification(token: token, code: code)
        }

        guard let first = segments.first, first.hasPrefix("@") else { return nil }

        if segments.count == 1 {
            return normalizedHandle(from: first).map { .profile(handle: $0) }
        }

        if isYear(segments[1]) || isUUID(segments[1]) {
            return .postURL(url.absoluteString)
        }

        return nil
    }

    static func isHackersPubWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "https" || scheme == "http") && url.host?.lowercased() == host
    }

    private static func pathSegments(from url: URL) -> [String] {
        url.path.split(separator: "/").compactMap { segment in
            let decoded = String(segment).removingPercentEncoding ?? String(segment)
            return decoded.isEmpty ? nil : decoded
        }
    }

    private static func normalizedHandle(from segment: String) -> String? {
        let username = String(segment.dropFirst())
        guard !username.isEmpty else { return nil }
        return username.contains("@") ? username : "\(username)@\(host)"
    }

    private static func queryValue(_ name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == name }?
            .value
    }

    private static func isUUID(_ value: String) -> Bool {
        value.range(of: uuidPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func isYear(_ value: String) -> Bool {
        value.range(of: yearPattern, options: .regularExpression) != nil
    }
}

enum DeepLinkPostResolver {
    static func resolvePostID(for url: String) async throws -> String? {
        let response = try await apolloClient.fetch(
            query: HackersPub.PostByUrlQuery(url: url),
            cachePolicy: .networkOnly
        )
        return response.data?.postByUrl?.id
    }
}
