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

        let urlPath = url.path
        if urlPath.hasPrefix("/@") {
            let handle = String(urlPath.dropFirst(2)) // Remove /@
            navigationCoordinator.navigateToProfile(handle: handle)
        }
    }
}

enum NavigationDestination: Hashable {
    case profile(handle: String)
    case post(id: String)
}

@Observable
class NavigationCoordinator {
    var path: [NavigationDestination] = []

    func navigateToProfile(handle: String) {
        path.append(.profile(handle: handle))
    }

    func navigateToPost(id: String) {
        path.append(.post(id: id))
    }

    func popToRoot() {
        path.removeAll()
    }
}
