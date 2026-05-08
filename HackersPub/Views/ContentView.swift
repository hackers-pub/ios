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
                Tab(value: "timeline") {
                    PersonalTimelineView(showingComposeView: $showingComposeView)
                } label: {
                    tabIcon("house", label: NSLocalizedString("tab.timeline", comment: "Timeline tab"))
                }

                Tab(value: "notifications") {
                    NotificationsView()
                } label: {
                    tabIcon("bell", label: NSLocalizedString("tab.notifications", comment: "Notifications tab"))
                }

                Tab(value: "explore") {
                    ExploreView(showingComposeView: $showingComposeView)
                } label: {
                    tabIcon("globe", label: NSLocalizedString("tab.explore", comment: "Explore tab"))
                }

                Tab(value: "bookmarks") {
                    NavigationStack(path: navigationCoordinator.pathBinding(for: .bookmarks)) {
                        BookmarksView(showingComposeView: $showingComposeView)
                    }
                } label: {
                    tabIcon("bookmark", label: NSLocalizedString("tab.bookmarks", comment: "Bookmarks tab"))
                }

                Tab(value: "search", role: .search) {
                    SearchView(searchText: $searchText, showingComposeView: $showingComposeView)
                        .searchable(text: $searchText)
                        .textInputAutocapitalization(.never)
                }
            } else {
                Tab(value: "local") {
                    LocalTimelineView()
                } label: {
                    tabIcon("cat", label: NSLocalizedString("tab.local", comment: "Local tab"))
                }
                .customizationID("local")

                Tab(value: "global") {
                    TimelineView()
                } label: {
                    tabIcon("globe", label: NSLocalizedString("tab.fediverse", comment: "Fediverse tab"))
                }

                Tab(value: "search", role: .search) {
                    SearchView(searchText: $searchText)
                        .searchable(text: $searchText)
                        .textInputAutocapitalization(.never)
                }

                Tab(value: "signIn") {
                    SignInView()
                } label: {
                    tabIcon(
                        "rectangle.portrait.and.arrow.right",
                        label: NSLocalizedString("tab.signIn", comment: "Sign in tab")
                    )
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

    private func tabIcon(_ systemImage: String, label: String) -> some View {
        Image(systemName: systemImage)
            .accessibilityLabel(label)
    }
}

#Preview {
    ContentView()
        .environment(AuthManager.shared)
}
