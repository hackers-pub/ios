//
//  HackersPubApp.swift
//  HackersPub
//
//  Created by Jihyeok Seo on 9/26/25.
//

import Kingfisher
import SwiftUI

@main
struct HackersPubApp: App {
    @State private var authManager = AuthManager.shared
    @State private var navigationCoordinator = NavigationCoordinator()
    @State private var notificationReadState = NotificationReadState()
    @State private var fontSettings = FontSettingsManager.shared
    @State private var externalURLRouter = ExternalURLRouter.shared
    @State private var browserSheetPresentation = BrowserSheetPresentationAdapter(router: .shared)

    init() {
        UserDefaults.standard.register(defaults: [
            "markdownMaxLength": 300
        ])
        setupImageCache()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .environment(navigationCoordinator)
                .environment(notificationReadState)
                .environment(externalURLRouter)
                .environmentObject(fontSettings)
                .onOpenURL { url in
                    handleURL(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    handleURL(url)
                }
                .background {
                    if let presentation = browserSheetPresentation.presentation {
                        BrowserSheetPresenter(presentation: presentation)
                            .id(presentation.id)
                    }
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

private struct BrowserSheetPresenter: View {
    let presentation: BrowserSheetPresentation

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .sheet(
                item: presentation.destinationBinding,
                onDismiss: presentation.onDismiss
            ) { destination in
                InAppBrowserSheetView(url: destination.url)
            }
    }
}

enum NavigationDestination: Hashable {
    case profile(handle: String)
    case post(id: String)
    case newsStory(id: String)
}

struct SearchRequest: Identifiable, Equatable {
    let id = UUID()
    let query: String
}

enum AppTab: String {
    case timeline
    case notifications
    case news
    case explore
    case bookmarks
    case search
    case local
    case global
    case signIn
}

enum AppTabSelectionPolicy {
    static func defaultTab(isAuthenticated: Bool) -> AppTab {
        isAuthenticated ? .timeline : .local
    }

    static func isSelectable(_ tab: AppTab, isAuthenticated: Bool) -> Bool {
        if isAuthenticated {
            return [.timeline, .notifications, .news, .explore, .bookmarks, .search].contains(tab)
        }

        return [.local, .global, .news, .search, .signIn].contains(tab)
    }

    static func normalized(_ tab: AppTab?, isAuthenticated: Bool) -> AppTab {
        guard let tab, isSelectable(tab, isAuthenticated: isAuthenticated) else {
            return defaultTab(isAuthenticated: isAuthenticated)
        }
        return tab
    }

    static func signInVerificationDestination(isAuthenticated: Bool, currentTab: AppTab) -> AppTab {
        guard !isAuthenticated else {
            return normalized(currentTab, isAuthenticated: true)
        }
        return .signIn
    }
}

enum NavigationRootError: Identifiable, Equatable {
    case signInVerificationFailed
    case signInVerificationAlreadySignedIn
    case signInVerificationSessionChanged

    var id: String {
        switch self {
        case .signInVerificationFailed:
            return "signInVerificationFailed"
        case .signInVerificationAlreadySignedIn:
            return "signInVerificationAlreadySignedIn"
        case .signInVerificationSessionChanged:
            return "signInVerificationSessionChanged"
        }
    }

    var title: String {
        switch self {
        case .signInVerificationFailed:
            return NSLocalizedString("signIn.verificationFailed.title", comment: "Sign-in verification failure title")
        case .signInVerificationAlreadySignedIn:
            return NSLocalizedString(
                "signIn.verificationAlreadySignedIn.title",
                comment: "Already signed-in verification link title"
            )
        case .signInVerificationSessionChanged:
            return NSLocalizedString(
                "signIn.verificationSessionChanged.title",
                comment: "Changed-session verification link title"
            )
        }
    }

    var message: String {
        switch self {
        case .signInVerificationFailed:
            return NSLocalizedString(
                "signIn.verificationFailed.message",
                comment: "Sign-in verification failure message"
            )
        case .signInVerificationAlreadySignedIn:
            return NSLocalizedString(
                "signIn.verificationAlreadySignedIn.message",
                comment: "Already signed-in verification link message"
            )
        case .signInVerificationSessionChanged:
            return NSLocalizedString(
                "signIn.verificationSessionChanged.message",
                comment: "Changed-session verification link message"
            )
        }
    }
}

@MainActor
struct NavigationRootNoticePresentationAdapter {
    let coordinator: NavigationCoordinator

    var notice: NavigationRootError? {
        coordinator.rootError
    }

    var title: String {
        notice?.title ?? ""
    }

    var message: String {
        notice?.message ?? ""
    }

    var isPresented: Binding<Bool> {
        Binding(
            get: { coordinator.rootError != nil },
            set: { isPresented in
                if !isPresented {
                    coordinator.dismissRootError()
                }
            }
        )
    }

    func dismiss() {
        coordinator.dismissRootError()
    }
}

@Observable
@MainActor
class NavigationCoordinator {
    var paths: [AppTab: [NavigationDestination]] = [:]
    var currentTab: AppTab = .timeline
    private(set) var requestedSearch: SearchRequest?
    var rootError: NavigationRootError?
    private(set) var hasRequestedTab = false
    @ObservationIgnored private var postRouteGeneration: UInt64 = 0
    @ObservationIgnored private var activePostRouteTask: Task<Void, Never>?

    init() {
        #if DEBUG
            if UITestLaunchConfiguration.seedsRouterSearch {
                openSearch(query: UITestLaunchConfiguration.seededRouterSearchQuery)
            }
        #endif
    }

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

    func navigateToNewsStory(id: String, on tab: AppTab = .news) {
        append(.newsStory(id: id), to: tab, requested: true)
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
        requestedSearch = SearchRequest(query: query)
        setCurrentTab(.search, requested: true)
    }

    func consumeRequestedSearch() -> SearchRequest? {
        defer { requestedSearch = nil }
        return requestedSearch
    }

    func consumeRequestedTab() {
        hasRequestedTab = false
    }

    func presentRootError(_ error: NavigationRootError) {
        rootError = error
    }

    func dismissRootError() {
        rootError = nil
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

    func beginPostRoute() -> UInt64 {
        precondition(postRouteGeneration < UInt64.max, "Post route generation exhausted")
        activePostRouteTask?.cancel()
        activePostRouteTask = nil
        postRouteGeneration += 1
        return postRouteGeneration
    }

    func ownsPostRoute(_ generation: UInt64) -> Bool {
        generation == postRouteGeneration
    }

    func retainPostRouteTask(_ task: Task<Void, Never>, for generation: UInt64) {
        guard ownsPostRoute(generation) else {
            task.cancel()
            return
        }
        activePostRouteTask = task
    }

    func finishPostRoute(_ generation: UInt64) {
        guard ownsPostRoute(generation) else { return }
        activePostRouteTask = nil
    }

    private func append(_ destination: NavigationDestination, to tab: AppTab, requested: Bool = false) {
        setCurrentTab(tab, requested: requested)
        var tabPath = paths[tab] ?? []
        guard tabPath.last != destination else { return }
        tabPath.append(destination)
        paths[tab] = tabPath
    }
}
