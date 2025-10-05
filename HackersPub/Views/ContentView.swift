import SwiftUI
@preconcurrency import Apollo

struct ContentView: View {
    @State private var searchText = ""
    @Environment(AuthManager.self) private var authManager
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @State private var selectedTab: String = "timeline"
    @State private var showingComposeView = false
    @State private var profileToShow: HackersPub.ActorByHandleQuery.Data.ActorByHandle?

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
        .sheet(item: $profileToShow) { actor in
            NavigationStack {
                ActorProfileView(actor: actor)
            }
        }
        .onChange(of: navigationCoordinator.shouldNavigateToProfile) { _, shouldNavigate in
            if shouldNavigate, let handle = navigationCoordinator.profileHandle {
                Task {
                    await fetchAndShowProfile(handle: handle)
                    navigationCoordinator.resetNavigation()
                }
            }
        }
    }

    private func fetchAndShowProfile(handle: String) async {
        do {
            let response = try await apolloClient.fetch(query: HackersPub.ActorByHandleQuery(handle: handle, after: nil))
            if let actor = response.data?.actorByHandle {
                profileToShow = actor
            }
        } catch {
            print("Error fetching profile: \(error)")
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            if authManager.isAuthenticated {
                Tab("Timeline", systemImage: "house", value: "timeline") {
                    PersonalTimelineView(showingComposeView: $showingComposeView)
                }

                Tab("Hackers' Pub", systemImage: "cat", value: "local") {
                    LocalTimelineView(showingComposeView: $showingComposeView)
                }
                .customizationID("local")

                Tab("Fediverse", systemImage: "globe", value: "global") {
                    TimelineView(showingComposeView: $showingComposeView)
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

                Tab("Timeline", systemImage: "rectangle.portrait.and.arrow.right", value: "timeline") {
                    SignInView()
                }
            }
        }
        .task {
            // Set default tab based on auth state
            selectedTab = "timeline"
        }
        .onChange(of: authManager.isAuthenticated) { _, _ in
            // Switch to timeline tab when auth state changes
            selectedTab = "timeline"
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthManager.shared)
}
