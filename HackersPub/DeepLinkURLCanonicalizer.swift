import Foundation

enum DeepLinkURLCanonicalizer {
    static func normalizedURLString(_ value: String) -> String? {
        guard var components = URLComponents(string: value) else { return nil }
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        components.fragment = nil

        // swiftlint:disable opening_brace
        if (components.scheme == "https" && components.port == 443) ||
            (components.scheme == "http" && components.port == 80)
        {
            components.port = nil
        }
        // swiftlint:enable opening_brace

        if components.path.count > 1 {
            components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            components.path = "/" + components.path
        }

        return components.url?.absoluteString
    }
}
