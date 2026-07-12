import Foundation

enum HTMLWebNavigationKind: Equatable {
    case linkActivated
    case formSubmitted
    case other
}

struct HTMLWebNavigationRequest: Equatable {
    let url: URL?
    let kind: HTMLWebNavigationKind
    let isMainFrame: Bool
}

/// Defines the only routes an embedded HTML document may take.
/// A `loadHTMLString` document begins at `about:blank`; after that, every
/// navigation stays in the native routing path or is cancelled.
enum HTMLWebNavigationPolicy {
    enum Decision: Equatable {
        case allowInitialDocument
        case route(URL)
        case cancel
    }

    static func decision(
        for request: HTMLWebNavigationRequest,
        allowsInitialDocumentLoad: Bool
    ) -> Decision {
        guard request.isMainFrame else { return .cancel }

        // swiftlint:disable opening_brace
        if allowsInitialDocumentLoad,
           request.kind == .other,
           request.url?.absoluteString == "about:blank"
        {
            return .allowInitialDocument
        }
        // swiftlint:enable opening_brace

        guard request.kind == .linkActivated,
              let url = request.url,
              isAllowedUserURL(url)
        else {
            return .cancel
        }

        return .route(url)
    }

    static func isAllowedUserURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host?.isEmpty == false
        else {
            return false
        }
        return true
    }
}
