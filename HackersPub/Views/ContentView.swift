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
                ProgressView("Loading...")
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
                Tab("Timeline", systemImage: "house", value: "timeline") {
                    PersonalTimelineView(showingComposeView: $showingComposeView)
                }

                Tab("Notifications", systemImage: "bell", value: "notifications") {
                    NotificationsView()
                }

                Tab("Explore", systemImage: "globe", value: "explore") {
                    ExploreView(showingComposeView: $showingComposeView)
                }

                Tab(value: "search", role: .search) {
                    SearchView(searchText: $searchText, showingComposeView: $showingComposeView)
                        .searchable(text: $searchText)
                        .textInputAutocapitalization(.never)
                }
            } else {
                Tab("Hackers' Pub", systemImage: "cat", value: "local") {
                    LocalTimelineView()
                }
                .customizationID("local")

                Tab("Fediverse", systemImage: "globe", value: "global") {
                    TimelineView()
                }

                Tab(value: "search", role: .search) {
                    SearchView(searchText: $searchText)
                        .searchable(text: $searchText)
                        .textInputAutocapitalization(.never)
                }

                Tab("Sign In", systemImage: "rectangle.portrait.and.arrow.right", value: "timeline") {
                    SignInView()
                }
            }
        }
        .task {
            // Set default tab based on auth state
            selectedTab = authManager.isAuthenticated ? "timeline" : "local"
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            // Switch to appropriate tab when auth state changes
            selectedTab = isAuth ? "timeline" : "local"
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthManager.shared)
}
