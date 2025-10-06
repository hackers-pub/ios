//
//  HackersPubApp.swift
//  HackersPub
//
//  Created by Jihyeok Seo on 9/26/25.
//

import SwiftUI
import Kingfisher

@main
struct HackersPubApp: App {
    @State private var authManager = AuthManager.shared
    @State private var navigationCoordinator = NavigationCoordinator()

    init() {
        setupImageCache()
    }

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

    private func setupImageCache() {
        let cache = Kingfisher.ImageCache.default
        cache.memoryStorage.config.countLimit = 50
    }
}

enum NavigationDestination: Hashable {
    case profile(handle: String)
    case post(id: String)
}

enum AppTab: String {
    case timeline
    case notifications
    case explore
    case search
    case local
    case global
    case signIn
}

@Observable
class NavigationCoordinator {
    var paths: [AppTab: [NavigationDestination]] = [:]
    var currentTab: AppTab = .timeline

    var path: [NavigationDestination] {
        get { paths[currentTab] ?? [] }
        set { paths[currentTab] = newValue }
    }

    func navigateToProfile(handle: String) {
        path.append(.profile(handle: handle))
    }

    func navigateToPost(id: String) {
        path.append(.post(id: id))
    }

    func popToRoot() {
        path.removeAll()
    }

    func setCurrentTab(_ tab: AppTab) {
        currentTab = tab
    }
}
