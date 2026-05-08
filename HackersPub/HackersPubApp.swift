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
    @State private var fontSettings = FontSettingsManager.shared
    @State private var externalURLRouter = ExternalURLRouter.shared

    init() {
        UserDefaults.standard.register(defaults: [
            "markdownMaxLength": 300,
        ])
        setupImageCache()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .environment(navigationCoordinator)
                .environment(externalURLRouter)
                .environmentObject(fontSettings)
                .onOpenURL { url in
                    handleURL(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    handleURL(url)
                }
                .sheet(
                    item: Binding(
                        get: { externalURLRouter.destination },
                        set: { externalURLRouter.destination = $0 }
                    )
                ) { destination in
                    InAppBrowserSheetView(url: destination.url)
                }
        }
    }

    private func handleURL(_ url: URL) {
        DeepLinkNavigator.open(
            url,
            authManager: authManager,
            navigationCoordinator: navigationCoordinator,
            externalURLRouter: externalURLRouter
        )
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
    case bookmarks
    case search
    case local
    case global
    case signIn
}

@Observable
@MainActor
class NavigationCoordinator {
    var paths: [AppTab: [NavigationDestination]] = [:]
    var currentTab: AppTab = .timeline
    var requestedSearchText: String?
    private(set) var hasRequestedTab = false

    var path: [NavigationDestination] {
        get { paths[currentTab] ?? [] }
        set { paths[currentTab] = newValue }
    }

    func pathBinding(for tab: AppTab) -> Binding<[NavigationDestination]> {
        Binding(
            get: { self.paths[tab] ?? [] },
            set: { self.paths[tab] = $0 }
        )
    }

    func navigateToProfile(handle: String) {
        append(.profile(handle: handle), to: currentTab)
    }

    func navigateToProfile(handle: String, on tab: AppTab) {
        append(.profile(handle: handle), to: tab, requested: true)
    }

    func navigateToPost(id: String) {
        append(.post(id: id), to: currentTab)
    }

    func navigateToPost(id: String, on tab: AppTab) {
        append(.post(id: id), to: tab, requested: true)
    }

    func popToRoot() {
        path.removeAll()
    }

    func setCurrentTab(_ tab: AppTab, requested: Bool = false) {
        if requested {
            hasRequestedTab = true
        }
        currentTab = tab
    }

    func openSearch(query: String) {
        requestedSearchText = query
        setCurrentTab(.search, requested: true)
    }

    func consumeRequestedTab() {
        hasRequestedTab = false
    }

    func hasPath(for tab: AppTab) -> Bool {
        !(paths[tab]?.isEmpty ?? true)
    }

    func movePath(from source: AppTab, to destination: AppTab) {
        guard let sourcePath = paths[source], !sourcePath.isEmpty else {
            setCurrentTab(destination)
            return
        }
        var destinationPath = paths[destination] ?? []
        destinationPath.append(contentsOf: sourcePath)
        paths[destination] = destinationPath
        paths[source] = []
        setCurrentTab(destination)
    }

    private func append(_ destination: NavigationDestination, to tab: AppTab, requested: Bool = false) {
        setCurrentTab(tab, requested: requested)
        var tabPath = paths[tab] ?? []
        guard tabPath.last != destination else { return }
        tabPath.append(destination)
        paths[tab] = tabPath
    }
}
