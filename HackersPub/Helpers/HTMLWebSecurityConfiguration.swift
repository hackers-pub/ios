import WebKit

/// Shared WebKit hardening for every app-owned HTML document.
@MainActor
enum HTMLWebSecurityConfiguration {
    static func make() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        return configuration
    }
}
