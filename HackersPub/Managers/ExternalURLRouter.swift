import Foundation
import SwiftUI
import UIKit

struct InAppBrowserDestination: Identifiable, Equatable {
    let id = UUID()
    let url: URL
}

@MainActor
@Observable
final class ExternalURLRouter {
    static let shared = ExternalURLRouter()

    static let useInAppBrowserKey = "links.useInAppBrowser"

    var destination: InAppBrowserDestination?

    var useInAppBrowser: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.useInAppBrowserKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Self.useInAppBrowserKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.useInAppBrowserKey)
        }
    }

    func open(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            UIApplication.shared.open(url)
            return
        }

        if useInAppBrowser {
            destination = InAppBrowserDestination(url: url)
        } else {
            UIApplication.shared.open(url)
        }
    }

    func dismissBrowser() {
        destination = nil
    }
}
