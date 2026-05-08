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
    private static let supportedHosts: Set<String> = [host]
    private static let customScheme = "hackerspub"
    private static let uuidPattern = #"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"#
    private static let yearPattern = #"^\d{4}$"#
    private static let profileSubpaths: Set<String> = [
        "articles",
        "drafts",
        "feed.xml",
        "followers",
        "following",
        "invite",
        "notes",
        "og",
        "settings",
        "shares",
    ]

    static func resolve(_ url: URL) -> HackersPubDeepLinkRoute? {
        guard let scheme = url.scheme?.lowercased() else { return nil }

        if scheme == customScheme {
            return resolveCustomScheme(url)
        }

        guard
            (scheme == "https" || scheme == "http"),
            let urlHost = url.host?.lowercased(),
            supportedHosts.contains(urlHost)
        else { return nil }

        return resolveWebURL(url)
    }

    static func isHackersPubWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        guard scheme == "https" || scheme == "http" else { return false }
        guard let urlHost = url.host?.lowercased() else { return false }
        return supportedHosts.contains(urlHost)
    }

    private static func resolveWebURL(_ url: URL) -> HackersPubDeepLinkRoute? {
        let segments = pathSegments(from: url)

        if segments.count == 2, segments[0] == "tags", !segments[1].isEmpty {
            return .tagSearch(segments[1])
        }

        if isSignInPath(segments) {
            guard let code = queryValue("code", in: url) else { return nil }
            return .signInVerification(token: signInToken(from: segments), code: code)
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

        if isProfileSubpath(segments[1]) {
            return normalizedHandle(from: first).map { .profile(handle: $0) }
        }

        if isPostPath(segments) {
            return .postURL(url.absoluteString)
        }

        return nil
    }

    private static func resolveCustomScheme(_ url: URL) -> HackersPubDeepLinkRoute? {
        let segments = customSchemeSegments(from: url)
        guard let first = segments.first else {
            return queryValue("url", in: url)
                .flatMap(URL.init(string:))
                .flatMap(resolve)
        }

        if first == "open" || first == "url" {
            return queryValue("url", in: url)
                .flatMap(URL.init(string:))
                .flatMap(resolve)
        }

        if first == "profile" {
            if let handle = queryValue("handle", in: url) {
                return normalizedHandleValue(handle).map { .profile(handle: $0) }
            }
            guard segments.count >= 2 else { return nil }
            return normalizedHandleValue(segments[1]).map { .profile(handle: $0) }
        }

        if first == "post" {
            guard let postURL = queryValue("url", in: url), URL(string: postURL) != nil else { return nil }
            return .postURL(postURL)
        }

        if first == "tags", segments.count >= 2, !segments[1].isEmpty {
            return .tagSearch(segments[1])
        }

        if first == "verify" {
            guard
                let token = queryValue("token", in: url),
                let code = queryValue("code", in: url)
            else { return nil }
            return .signInVerification(token: token, code: code)
        }

        if isSignInPath(segments) {
            guard let code = queryValue("code", in: url) else { return nil }
            return .signInVerification(token: signInToken(from: segments), code: code)
        }

        if first.hasPrefix("@") {
            if segments.count == 1 || isProfileSubpath(segments[1]) {
                return normalizedHandle(from: first).map { .profile(handle: $0) }
            }
            if isPostPath(segments) {
                return postURL(fromCustomSchemeSegments: segments).map { .postURL($0) }
            }
        }

        return nil
    }

    private static func pathSegments(from url: URL) -> [String] {
        url.path.split(separator: "/").compactMap { segment in
            let decoded = String(segment).removingPercentEncoding ?? String(segment)
            return decoded.isEmpty ? nil : decoded
        }
    }

    private static func customSchemeSegments(from url: URL) -> [String] {
        var segments: [String] = []
        if let host = url.host?.removingPercentEncoding, !host.isEmpty {
            segments.append(url.user == nil ? host : "@\(host)")
        }
        segments.append(contentsOf: pathSegments(from: url))
        return segments
    }

    private static func postURL(fromCustomSchemeSegments segments: [String]) -> String? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/" + segments
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0 }
            .joined(separator: "/")
        return components.url?.absoluteString
    }

    private static func normalizedHandle(from segment: String) -> String? {
        let username = String(segment.dropFirst())
        return normalizedHandleValue(username)
    }

    private static func normalizedHandleValue(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let handle = trimmed.hasPrefix("@") ? String(trimmed.dropFirst()) : trimmed
        guard !handle.isEmpty else { return nil }
        return handle.contains("@") ? handle : "\(handle)@\(host)"
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

    private static func isProfileSubpath(_ value: String) -> Bool {
        profileSubpaths.contains(value.lowercased())
    }

    private static func isPostPath(_ segments: [String]) -> Bool {
        guard segments.count >= 2 else { return false }
        if isUUID(segments[1]) || isYear(segments[1]) {
            return true
        }
        return segments.count >= 3 && segments[1] == "polls" && isUUID(segments[2])
    }

    private static func isSignInPath(_ segments: [String]) -> Bool {
        if segments.count >= 3, segments[0] == "sign", segments[1] == "in" {
            return true
        }
        return segments.count >= 4 &&
            segments[0] == "applink" &&
            segments[1] == "sign" &&
            segments[2] == "in"
    }

    private static func signInToken(from segments: [String]) -> String {
        segments[0] == "applink" ? segments[3] : segments[2]
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
