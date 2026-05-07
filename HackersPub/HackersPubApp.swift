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
        guard let route = HackersPubURLRouter.resolve(url) else {
            if HackersPubURLRouter.isHackersPubWebURL(url) {
                externalURLRouter.open(url)
            }
            return
        }

        switch route {
        case .profile(let handle):
            navigationCoordinator.navigateToProfile(
                handle: handle,
                on: authManager.isAuthenticated ? .timeline : .local
            )

        case .postURL(let urlString):
            let tab: AppTab = authManager.isAuthenticated ? .timeline : .local
            navigationCoordinator.setCurrentTab(tab, requested: true)
            Task {
                do {
                    if let postID = try await DeepLinkPostResolver.resolvePostID(for: urlString) {
                        await MainActor.run {
                            navigationCoordinator.navigateToPost(id: postID, on: tab)
                        }
                    } else {
                        openFallbackURL(urlString)
                    }
                } catch {
                    print("Error resolving post URL: \(error)")
                    openFallbackURL(urlString)
                }
            }

        case .signInVerification(let token, let code):
            navigationCoordinator.setCurrentTab(.signIn, requested: true)
            Task {
                do {
                    try await authManager.completeLoginChallenge(token: token, code: code)
                } catch {
                    print("Error completing sign-in link: \(error)")
                }
            }

        case .tagSearch(let tag):
            navigationCoordinator.openSearch(query: tag)
        }
    }

    private func setupImageCache() {
        let cache = Kingfisher.ImageCache.default
        cache.memoryStorage.config.countLimit = 50
    }

    @MainActor
    private func openFallbackURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        externalURLRouter.open(url)
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
        append(.post(id: id), to: tab)
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
