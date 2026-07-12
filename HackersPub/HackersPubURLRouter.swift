import Foundation

enum HackersPubURLRouter {
    private static let host = "hackers.pub"
    private static let supportedHosts: Set<String> = [host, "www.hackers.pub"]
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
        "shares"
    ]

    static func resolve(_ url: URL) -> HackersPubDeepLinkRoute? {
        guard let scheme = url.scheme?.lowercased() else { return nil }

        if scheme == customScheme {
            return resolveCustomScheme(url)
        }

        guard isHackersPubWebURL(url) else { return nil }
        return resolveWebURL(url)
    }

    static func isOwnedCustomScheme(_ url: URL) -> Bool {
        url.scheme?.caseInsensitiveCompare(customScheme) == .orderedSame
    }

    static func isHackersPubWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        guard let urlHost = url.host?.lowercased() else { return false }
        guard supportedHosts.contains(urlHost) else { return false }

        switch scheme {
        case "https":
            return url.port == nil || url.port == 443
        case "http":
            return url.port == nil || url.port == 80
        default:
            return false
        }
    }

    private static func resolveWebURL(_ url: URL) -> HackersPubDeepLinkRoute? {
        let segments = DeepLinkURLPath.decodedSegments(from: url)

        if segments.count == 2, segments[0].lowercased() == "tags", !segments[1].isEmpty {
            return .tagSearch(segments[1])
        }

        if segments.count == 2, segments[0].lowercased() == "news", isUUID(segments[1]) {
            return .newsStory(id: segments[1])
        }

        if isSignInPath(segments) {
            return signInRoute(from: segments, url: url)
        }

        if segments.count == 1, segments[0] == "verify" {
            return verificationRoute(from: url)
        }

        return profileOrPostRoute(from: segments, originalURL: url)
    }

    private static func resolveCustomScheme(_ url: URL) -> HackersPubDeepLinkRoute? {
        guard let segments = customSchemeSegments(from: url) else { return nil }
        guard let rawFirst = segments.first else { return routedURL(from: url) }

        if let route = explicitCustomRoute(
            command: rawFirst.lowercased(),
            segments: segments,
            url: url
        ) {
            return route
        }

        return implicitCustomRoute(rawFirst: rawFirst, segments: segments, url: url)
    }

    private static func explicitCustomRoute(
        command: String,
        segments: [String],
        url: URL
    ) -> HackersPubDeepLinkRoute? {
        switch command {
        case "open", "url":
            return routedURL(from: url)
        case "profile":
            return customProfileRoute(from: segments, url: url)
        case "post":
            return customPostRoute(from: url)
        case "tags":
            return customTagRoute(from: segments)
        case "news":
            return customNewsRoute(from: segments)
        case "verify":
            return verificationRoute(from: url)
        default:
            return nil
        }
    }

    private static func implicitCustomRoute(
        rawFirst: String,
        segments: [String],
        url: URL
    ) -> HackersPubDeepLinkRoute? {
        if isSignInPath(segments) {
            return signInRoute(from: segments, url: url)
        }

        guard rawFirst.hasPrefix("@") else { return nil }
        return customAuthorityRoute(from: segments)
    }

    private static func routedURL(from url: URL) -> HackersPubDeepLinkRoute? {
        queryValue("url", in: url)
            .flatMap(URL.init(string:))
            .flatMap(resolve)
    }

    private static func customProfileRoute(
        from segments: [String],
        url: URL
    ) -> HackersPubDeepLinkRoute? {
        if let handle = queryValue("handle", in: url) {
            return normalizedHandleValue(handle).map { .profile(handle: $0) }
        }
        guard segments.count >= 2 else { return nil }
        return normalizedHandleValue(segments[1]).map { .profile(handle: $0) }
    }

    private static func customPostRoute(from url: URL) -> HackersPubDeepLinkRoute? {
        guard let postURL = queryValue("url", in: url), URL(string: postURL) != nil else {
            return nil
        }
        return .postURL(postURL)
    }

    private static func customTagRoute(from segments: [String]) -> HackersPubDeepLinkRoute? {
        guard segments.count >= 2, !segments[1].isEmpty else { return nil }
        return .tagSearch(segments[1])
    }

    private static func customNewsRoute(from segments: [String]) -> HackersPubDeepLinkRoute? {
        guard segments.count >= 2, isUUID(segments[1]) else { return nil }
        return .newsStory(id: segments[1])
    }

    private static func customAuthorityRoute(
        from segments: [String]
    ) -> HackersPubDeepLinkRoute? {
        guard let first = segments.first else { return nil }
        if segments.count == 1 || isProfileSubpath(segments[1]) {
            return normalizedHandle(from: first).map { .profile(handle: $0) }
        }
        guard isPostPath(segments) else { return nil }
        return postURL(fromCustomSchemeSegments: segments).map { .postURL($0) }
    }

    private static func profileOrPostRoute(
        from segments: [String],
        originalURL: URL
    ) -> HackersPubDeepLinkRoute? {
        guard let first = segments.first, first.hasPrefix("@") else { return nil }
        if segments.count == 1 || isProfileSubpath(segments[1]) {
            return normalizedHandle(from: first).map { .profile(handle: $0) }
        }
        return isPostPath(segments) ? .postURL(originalURL.absoluteString) : nil
    }

    private static func signInRoute(
        from segments: [String],
        url: URL
    ) -> HackersPubDeepLinkRoute? {
        guard let code = queryValue("code", in: url) else { return nil }
        return .signInVerification(token: signInToken(from: segments), code: code)
    }

    private static func verificationRoute(from url: URL) -> HackersPubDeepLinkRoute? {
        guard
            let token = queryValue("token", in: url),
            let code = queryValue("code", in: url)
        else { return nil }
        return .signInVerification(token: token, code: code)
    }

    private static func customSchemeSegments(from url: URL) -> [String]? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        guard let authority = CustomSchemeAuthority(components: components) else { return nil }

        var segments = authority.segment.map { [$0] } ?? []
        segments.append(contentsOf: DeepLinkURLPath.decodedSegments(from: url))
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
        normalizedHandleValue(String(segment.dropFirst()))
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
        return segments.count >= 3 && segments[1].lowercased() == "polls" && isUUID(segments[2])
    }

    private static func isSignInPath(_ segments: [String]) -> Bool {
        if segments.count >= 3, segments[0].lowercased() == "sign", segments[1].lowercased() == "in" {
            return true
        }
        return segments.count >= 4 &&
            segments[0].lowercased() == "applink" &&
            segments[1].lowercased() == "sign" &&
            segments[2].lowercased() == "in"
    }

    private static func signInToken(from segments: [String]) -> String {
        segments[0].lowercased() == "applink" ? segments[3] : segments[2]
    }
}
