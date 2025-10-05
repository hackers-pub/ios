//
//  HackersPubApp.swift
//  HackersPub
//
//  Created by Jihyeok Seo on 9/26/25.
//

import SwiftUI

@main
struct HackersPubApp: App {
    @State private var authManager = AuthManager.shared
    @State private var navigationCoordinator = NavigationCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .environment(navigationCoordinator)
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }

    private func handleURL(_ url: URL) {
        // Handle hackers.pub URLs like https://hackers.pub/@username
        guard url.host == "hackers.pub" else { return }

        let path = url.path
        if path.hasPrefix("/@") {
            let handle = String(path.dropFirst(2)) // Remove /@
            navigationCoordinator.navigateToProfile(handle: handle)
        }
    }
}

@Observable
class NavigationCoordinator {
    var profileHandle: String?
    var shouldNavigateToProfile = false

    func navigateToProfile(handle: String) {
        profileHandle = handle
        shouldNavigateToProfile = true
    }

    func resetNavigation() {
        shouldNavigateToProfile = false
    }
}
