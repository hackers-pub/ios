@testable import HackersPub
import Testing
import WebKit

@MainActor
struct HTMLWebSecurityConfigurationTests {
    @Test
    func sharedWebConfigurationDisablesContentJavaScriptAndPopups() {
        let configuration = HTMLWebSecurityConfiguration.make()

        #expect(!configuration.defaultWebpagePreferences.allowsContentJavaScript)
        #expect(!configuration.preferences.javaScriptCanOpenWindowsAutomatically)
    }
}
