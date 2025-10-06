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

                Tab(NSLocalizedString("tab.signIn", comment: "Sign in tab"), systemImage: "rectangle.portrait.and.arrow.right", value: "timeline") {
                    SignInView()
                }
            }
        }
        .task {
            // Set default tab based on auth state
            selectedTab = authManager.isAuthenticated ? "timeline" : "local"
            updateCurrentTab()
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            // Switch to appropriate tab when auth state changes
            selectedTab = isAuth ? "timeline" : "local"
            updateCurrentTab()
        }
        .onChange(of: selectedTab) { _, _ in
            updateCurrentTab()
        }
    }

    private func updateCurrentTab() {
        navigationCoordinator.setCurrentTab(AppTab(rawValue: selectedTab) ?? .timeline)
    }
}

#Preview {
    ContentView()
        .environment(AuthManager.shared)
}
