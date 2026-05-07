import SwiftUI
@preconcurrency import Apollo

struct ContentView: View {
    @State private var searchText = ""
    @Environment(AuthManager.self) private var authManager
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
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
                Tab(NSLocalizedString("tab.timeline", comment: "Timeline tab"), systemImage: "house", value: "timeline") {
                    PersonalTimelineView(showingComposeView: $showingComposeView)
                }

                Tab(NSLocalizedString("tab.notifications", comment: "Notifications tab"), systemImage: "bell", value: "notifications") {
                    NotificationsView()
                }

                Tab(NSLocalizedString("tab.explore", comment: "Explore tab"), systemImage: "globe", value: "explore") {
                    ExploreView(showingComposeView: $showingComposeView)
                }

                Tab(value: "search", role: .search) {
                    SearchView(searchText: $searchText, showingComposeView: $showingComposeView)
                        .searchable(text: $searchText)
                        .textInputAutocapitalization(.never)
                }
            } else {
                Tab(NSLocalizedString("tab.local", comment: "Local tab"), systemImage: "cat", value: "local") {
                    LocalTimelineView()
                }
                .customizationID("local")

                Tab(NSLocalizedString("tab.fediverse", comment: "Fediverse tab"), systemImage: "globe", value: "global") {
                    TimelineView()
                }

                Tab(value: "search", role: .search) {
                    SearchView(searchText: $searchText)
                        .searchable(text: $searchText)
                        .textInputAutocapitalization(.never)
                }

                Tab(NSLocalizedString("tab.signIn", comment: "Sign in tab"), systemImage: "rectangle.portrait.and.arrow.right", value: "signIn") {
                    SignInView()
                }
            }
        }
        .task {
            // Set default tab based on auth state
            if navigationCoordinator.hasRequestedTab {
                selectedTab = navigationCoordinator.currentTab.rawValue
                navigationCoordinator.consumeRequestedTab()
            } else {
                selectedTab = authManager.isAuthenticated ? "timeline" : "local"
                updateCurrentTab()
            }
            applyRequestedSearchText()
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            // Switch to appropriate tab when auth state changes
            if navigationCoordinator.hasRequestedTab {
                selectedTab = navigationCoordinator.currentTab.rawValue
                navigationCoordinator.consumeRequestedTab()
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
}

#Preview {
    ContentView()
        .environment(AuthManager.shared)
}
