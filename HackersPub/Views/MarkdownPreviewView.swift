import SwiftUI
import WebKit

struct FontSettingsSnapshot: Equatable {
    let fontName: String
    let sizeMultiplier: Double
    let useSystemDynamicType: Bool

    init(from manager: FontSettingsManager) {
        fontName = manager.selectedFontName
        sizeMultiplier = manager.fontSizeMultiplier
        useSystemDynamicType = manager.useSystemDynamicType
    }
}

#if os(macOS)
    struct MarkdownPreviewView: NSViewRepresentable {
        let html: String
        @Binding var isLoading: Bool
        @ObservedObject private var fontSettings = FontSettingsManager.shared

        func makeNSView(context: Context) -> WKWebView {
            let webView = WKWebView()
            webView.setValue(false, forKey: "drawsBackground")
            webView.navigationDelegate = context.coordinator
            return webView
        }

        func updateNSView(_ webView: WKWebView, context: Context) {
            // Update the coordinator's binding reference
            context.coordinator.isLoading = $isLoading

            // Check if HTML or font settings have changed
            let currentFontSettings = FontSettingsSnapshot(from: fontSettings)
            let contentChanged = context.coordinator.lastHTML != html
            let fontChanged = context.coordinator.lastFontSettings != currentFontSettings

            if contentChanged || fontChanged {
                context.coordinator.lastHTML = html
                context.coordinator.lastFontSettings = currentFontSettings
                webView.loadHTMLString(html, baseURL: nil)
            }
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(isLoading: $isLoading)
        }

        class Coordinator: NSObject, WKNavigationDelegate {
            var isLoading: Binding<Bool>
            var lastHTML: String = ""
            var lastFontSettings: FontSettingsSnapshot?

            init(isLoading: Binding<Bool>) {
                self.isLoading = isLoading
            }

            func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
                isLoading.wrappedValue = true
            }

            func webView(_: WKWebView, didFinish _: WKNavigation!) {
                isLoading.wrappedValue = false
            }

            func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
                isLoading.wrappedValue = false
            }

            // swiftlint:disable:next line_length
            func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
                if navigationAction.navigationType == .linkActivated {
                    if let url = navigationAction.request.url {
                        NSWorkspace.shared.open(url)
                        decisionHandler(.cancel)
                        return
                    }
                }
                decisionHandler(.allow)
            }
        }
    }
#else
    struct MarkdownPreviewView: UIViewRepresentable {
        let html: String
        @Binding var isLoading: Bool
        @ObservedObject private var fontSettings = FontSettingsManager.shared
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize

        func makeUIView(context: Context) -> WKWebView {
            let webView = WKWebView()
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.navigationDelegate = context.coordinator
            return webView
        }

        func updateUIView(_ webView: WKWebView, context: Context) {
            // Update the coordinator's binding reference
            context.coordinator.isLoading = $isLoading

            // Check if HTML or font settings have changed
            let currentFontSettings = FontSettingsSnapshot(from: fontSettings)
            let contentChanged = context.coordinator.lastHTML != html
            let fontChanged = context.coordinator.lastFontSettings != currentFontSettings
            let dynamicTypeChanged = context.coordinator.lastDynamicTypeSize != dynamicTypeSize

            if contentChanged || fontChanged || dynamicTypeChanged {
                context.coordinator.lastHTML = html
                context.coordinator.lastFontSettings = currentFontSettings
                context.coordinator.lastDynamicTypeSize = dynamicTypeSize
                webView.loadHTMLString(html, baseURL: nil)
            }
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(isLoading: $isLoading)
        }

        class Coordinator: NSObject, WKNavigationDelegate {
            var isLoading: Binding<Bool>
            var lastHTML: String = ""
            var lastFontSettings: FontSettingsSnapshot?
            var lastDynamicTypeSize: DynamicTypeSize?

            init(isLoading: Binding<Bool>) {
                self.isLoading = isLoading
            }

            func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
                isLoading.wrappedValue = true
            }

            func webView(_: WKWebView, didFinish _: WKNavigation!) {
                isLoading.wrappedValue = false
            }

            func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
                isLoading.wrappedValue = false
            }

            // swiftlint:disable:next line_length
            func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
                if navigationAction.navigationType == .linkActivated {
                    if let url = navigationAction.request.url {
                        UIApplication.shared.open(url)
                        decisionHandler(.cancel)
                        return
                    }
                }
                decisionHandler(.allow)
            }
        }
    }
#endif
