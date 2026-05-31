import SwiftUI
@preconcurrency import Apollo

struct ContentView: View {
    private static let tabViewCustomizationStorageKey = "tabViewCustomization"

    @State private var searchText = ""
    @Environment(AuthManager.self) private var authManager
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @State private var tabViewCustomization = TabViewCustomization()
    @State private var selectedTab: String = "timeline"
    @State private var showingComposeView = false

    var body: some View {
        Group {
            if authManager.isLoading {
                ProgressView(NSLocalizedString("timeline.loading", comment: "Loading indicator"))
            } else {
                mainContent
            }
        }
        .sheet(isPresented: $showingComposeView) {
            ComposeView()
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            if authManager.isAuthenticated {
                Tab(NSLocalizedString("tab.timeline", comment: "Timeline tab"), systemImage: "house", value: "timeline", role: nil) {
                    PersonalTimelineView(showingComposeView: $showingComposeView)
                }
                .customizationID("timeline")
                .customizationBehavior(.disabled, for: .tabBar)

                Tab(NSLocalizedString("tab.notifications", comment: "Notifications tab"), systemImage: "bell", value: "notifications", role: nil) {
                    NotificationsView()
                }
                .customizationID("notifications")

                Tab(NSLocalizedString("tab.news", comment: "News tab"), systemImage: "newspaper", value: "news", role: nil) {
                    NewsView()
                }
                .customizationID("news")

                Tab(NSLocalizedString("tab.explore", comment: "Explore tab"), systemImage: "globe", value: "explore", role: nil) {
                    ExploreView(showingComposeView: $showingComposeView)
                }
                .customizationID("explore")

                Tab(NSLocalizedString("tab.bookmarks", comment: "Bookmarks tab"), systemImage: "bookmark", value: "bookmarks", role: nil) {
                    NavigationStack(path: navigationCoordinator.pathBinding(for: .bookmarks)) {
                        BookmarksView(showingComposeView: $showingComposeView)
                    }
                }
                .customizationID("bookmarks")
                .defaultVisibility(.hidden, for: .tabBar)

                Tab(NSLocalizedString("tab.search", comment: "Search tab"), systemImage: "magnifyingglass", value: "search", role: .search) {
                    SearchView(searchText: $searchText, showingComposeView: $showingComposeView)
                        .searchable(text: $searchText)
                        .textInputAutocapitalization(.never)
                }
                .customizationID("search")
            } else {
                Tab(NSLocalizedString("tab.local", comment: "Local tab"), systemImage: "cat", value: "local", role: nil) {
                    LocalTimelineView()
                }
                .customizationID("local")
                .customizationBehavior(.disabled, for: .tabBar)

                Tab(NSLocalizedString("tab.fediverse", comment: "Fediverse tab"), systemImage: "globe", value: "global", role: nil) {
                    TimelineView()
                }
                .customizationID("global")

                Tab(NSLocalizedString("tab.news", comment: "News tab"), systemImage: "newspaper", value: "news", role: nil) {
                    NewsView()
                }
                .customizationID("news")

                Tab(NSLocalizedString("tab.search", comment: "Search tab"), systemImage: "magnifyingglass", value: "search", role: .search) {
                    SearchView(searchText: $searchText)
                        .searchable(text: $searchText)
                        .textInputAutocapitalization(.never)
                }
                .customizationID("search")

                Tab(NSLocalizedString("tab.signIn", comment: "Sign in tab"), systemImage: "rectangle.portrait.and.arrow.right", value: "signIn", role: nil) {
                    SignInView()
                }
                .customizationID("signIn")
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewCustomization($tabViewCustomization)
        .task {
            tabViewCustomization = Self.loadTabViewCustomization(isAuthenticated: authManager.isAuthenticated)
            // Set default tab based on auth state
            if !applyRequestedTabIfAvailable(isAuthenticated: authManager.isAuthenticated) {
                selectedTab = authManager.isAuthenticated ? "timeline" : "local"
                updateCurrentTab()
            }
            applyRequestedSearchText()
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            tabViewCustomization = Self.loadTabViewCustomization(isAuthenticated: isAuth)
            // Switch to appropriate tab when auth state changes
            if applyRequestedTabIfAvailable(isAuthenticated: isAuth) {
                return
            } else if migrateDeepLinkPathIfNeeded(isAuthenticated: isAuth) {
                return
            } else {
                selectedTab = isAuth ? "timeline" : "local"
                updateCurrentTab()
            }
        }
        .onChange(of: selectedTab) { _, _ in
            updateCurrentTab()
        }
        .onChange(of: navigationCoordinator.currentTab) { _, tab in
            guard selectedTab != tab.rawValue else { return }
            selectedTab = tab.rawValue
        }
        .onChange(of: navigationCoordinator.requestedSearchText) { _, _ in
            applyRequestedSearchText()
        }
        .onChange(of: tabViewCustomization) { _, customization in
            Self.saveTabViewCustomization(customization, isAuthenticated: authManager.isAuthenticated)
        }
    }

    private func updateCurrentTab() {
        let tab = AppTab(rawValue: selectedTab) ?? .timeline
        guard navigationCoordinator.currentTab != tab else { return }
        navigationCoordinator.setCurrentTab(tab)
    }

    private func applyRequestedSearchText() {
        guard let query = navigationCoordinator.requestedSearchText else { return }
        searchText = query
    }

    @discardableResult
    private func applyRequestedTabIfAvailable(isAuthenticated: Bool) -> Bool {
        guard navigationCoordinator.hasRequestedTab else { return false }

        let requestedTab = navigationCoordinator.currentTab
        navigationCoordinator.consumeRequestedTab()

        guard isSelectable(tab: requestedTab, isAuthenticated: isAuthenticated) else {
            return false
        }

        selectedTab = requestedTab.rawValue
        return true
    }

    private func isSelectable(tab: AppTab, isAuthenticated: Bool) -> Bool {
        if isAuthenticated {
            return [.timeline, .notifications, .news, .explore, .bookmarks, .search].contains(tab)
        }

        return [.local, .global, .news, .search, .signIn].contains(tab)
    }

    private func migrateDeepLinkPathIfNeeded(isAuthenticated: Bool) -> Bool {
        if isAuthenticated, navigationCoordinator.hasPath(for: .local) {
            navigationCoordinator.movePath(from: .local, to: .timeline)
            selectedTab = AppTab.timeline.rawValue
            return true
        }

        if !isAuthenticated, navigationCoordinator.hasPath(for: .timeline) {
            navigationCoordinator.movePath(from: .timeline, to: .local)
            selectedTab = AppTab.local.rawValue
            return true
        }

        return false
    }

    private static func loadTabViewCustomization(isAuthenticated: Bool) -> TabViewCustomization {
        guard
            let data = UserDefaults.standard.data(forKey: tabViewCustomizationStorageKey(isAuthenticated: isAuthenticated)),
            let customization = try? JSONDecoder().decode(TabViewCustomization.self, from: data)
        else {
            return TabViewCustomization()
        }

        return customization
    }

    private static func saveTabViewCustomization(_ customization: TabViewCustomization, isAuthenticated: Bool) {
        guard let data = try? JSONEncoder().encode(customization) else { return }
        UserDefaults.standard.set(data, forKey: tabViewCustomizationStorageKey(isAuthenticated: isAuthenticated))
    }

    private static func tabViewCustomizationStorageKey(isAuthenticated: Bool) -> String {
        "\(tabViewCustomizationStorageKey).\(isAuthenticated ? "authenticated" : "guest")"
    }
}

#Preview {
    ContentView()
        .environment(AuthManager.shared)
}
