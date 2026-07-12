import Foundation

enum ExternalURLOpeningPolicy {
    enum Action: Equatable {
        case consumeOwnedScheme
        case inAppBrowser
        case systemOpen
    }

    static func action(
        for url: URL,
        useInAppBrowser: Bool,
        forceInAppBrowser: Bool = false
    ) -> Action {
        if HackersPubURLRouter.isOwnedCustomScheme(url) {
            return .consumeOwnedScheme
        }

        guard isWebURL(url) else { return .systemOpen }
        return forceInAppBrowser || useInAppBrowser ? .inAppBrowser : .systemOpen
    }

    static func isWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}

enum RendererLinkRoutingPolicy {
    enum Action: Equatable {
        case deepLink
        case consumeOwnedScheme
        case inAppBrowser
        case external
    }

    static func action(for url: URL, hasNavigationCoordinator: Bool) -> Action {
        if HackersPubURLRouter.isOwnedCustomScheme(url) {
            return hasNavigationCoordinator ? .deepLink : .consumeOwnedScheme
        }

        guard ExternalURLOpeningPolicy.isWebURL(url) else {
            return .external
        }

        if hasNavigationCoordinator {
            return .deepLink
        }

        return HackersPubURLRouter.isHackersPubWebURL(url) ? .inAppBrowser : .external
    }
}

enum RendererWebViewNavigationPolicy {
    enum Action: Equatable {
        case allow
        case cancel
    }

    static func action(for url: URL) -> Action {
        HackersPubURLRouter.isOwnedCustomScheme(url) ? .cancel : .allow
    }
}

enum SafariPreviewPolicy {
    static func url(for url: URL) -> URL? {
        ExternalURLOpeningPolicy.isWebURL(url) ? url : nil
    }
}
