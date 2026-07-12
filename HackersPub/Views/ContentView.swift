@preconcurrency import Apollo
import SwiftUI

enum TabCustomizationScope: String {
    case guest
    case authenticated

    init(isAuthenticated: Bool) {
        self = isAuthenticated ? .authenticated : .guest
    }
}

struct TabCustomizationPersistenceContext: Equatable {
    let scope: TabCustomizationScope
    let epoch: UInt64
}

struct TabCustomizationPersistenceCoordinator<Value> {
    private(set) var activeContext: TabCustomizationPersistenceContext
    private(set) var value: Value
    private(set) var isRestoring = false

    var activeScope: TabCustomizationScope {
        activeContext.scope
    }

    init(scope: TabCustomizationScope, value: Value) {
        activeContext = TabCustomizationPersistenceContext(scope: scope, epoch: 1)
        self.value = value
    }

    @discardableResult
    mutating func transition(
        to scope: TabCustomizationScope,
        persist: (TabCustomizationPersistenceContext, Value) -> Void,
        restore: (TabCustomizationPersistenceContext) -> Value
    ) -> TabCustomizationPersistenceContext {
        let previousContext = activeContext
        precondition(previousContext.epoch < UInt64.max, "Tab customization epoch exhausted")
        let nextContext = TabCustomizationPersistenceContext(
            scope: scope,
            epoch: previousContext.epoch + 1
        )

        guard previousContext.scope != scope else {
            activeContext = nextContext
            return nextContext
        }

        guard activeContext == previousContext else { return activeContext }
        persist(previousContext, value)
        activeContext = nextContext
        isRestoring = true
        guard activeContext == nextContext else { return activeContext }
        let restoredValue = restore(nextContext)
        guard activeContext == nextContext else { return activeContext }
        value = restoredValue
        isRestoring = false
        return nextContext
    }

    @discardableResult
    mutating func apply(
        _ value: Value,
        from context: TabCustomizationPersistenceContext,
        persist: (TabCustomizationPersistenceContext, Value) -> Void
    ) -> Bool {
        guard !isRestoring, context == activeContext else { return false }

        self.value = value
        persist(context, value)
        return true
    }
}

struct TabCustomizationPersistenceAdapter<Value> {
    private var coordinator: TabCustomizationPersistenceCoordinator<Value>
    private let persist: (TabCustomizationPersistenceContext, Value) -> Void
    private let restore: (TabCustomizationPersistenceContext) -> Value

    init(
        scope: TabCustomizationScope,
        value: Value,
        persist: @escaping (TabCustomizationPersistenceContext, Value) -> Void,
        restore: @escaping (TabCustomizationPersistenceContext) -> Value
    ) {
        coordinator = TabCustomizationPersistenceCoordinator(scope: scope, value: value)
        self.persist = persist
        self.restore = restore
    }

    var activeScope: TabCustomizationScope {
        coordinator.activeScope
    }

    var activeContext: TabCustomizationPersistenceContext {
        coordinator.activeContext
    }

    var value: Value {
        coordinator.value
    }

    @discardableResult
    mutating func transition(to scope: TabCustomizationScope) -> TabCustomizationPersistenceContext {
        coordinator.transition(to: scope, persist: persist, restore: restore)
    }

    @discardableResult
    mutating func apply(
        _ value: Value,
        from context: TabCustomizationPersistenceContext
    ) -> Bool {
        coordinator.apply(value, from: context, persist: persist)
    }
}

enum TabCustomizationStorage {
    private static let baseStorageKey = "tabViewCustomization"

    static func load(for scope: TabCustomizationScope) -> TabViewCustomization {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey(for: scope)),
            let customization = try? JSONDecoder().decode(TabViewCustomization.self, from: data)
        else {
            return TabViewCustomization()
        }

        return customization
    }

    static func save(_ customization: TabViewCustomization, for scope: TabCustomizationScope) {
        guard let data = try? JSONEncoder().encode(customization) else { return }
        UserDefaults.standard.set(data, forKey: storageKey(for: scope))
    }

    private static func storageKey(for scope: TabCustomizationScope) -> String {
        "\(baseStorageKey).\(scope.rawValue)"
    }
}

@MainActor
struct ContentViewSearchRequestConsumer {
    let navigationCoordinator: NavigationCoordinator

    @discardableResult
    func consume(forward: (SearchRequest) -> Void) -> SearchRequest? {
        guard let request = navigationCoordinator.consumeRequestedSearch() else { return nil }
        forward(request)
        return request
    }

    @discardableResult
    func consume(_ apply: (String) -> Void) -> SearchRequest? {
        consume(forward: { apply($0.query) })
    }
}

struct ContentView: View {
    @State private var searchText = ""
    @State private var searchSubmitRequest: SearchSubmitRequest?
    @State private var routerSearchRequest: SearchRequest?
    @State private var searchSubmitGeneration = 0
    @Environment(AuthManager.self) private var authManager
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @Environment(NotificationReadState.self) private var notificationReadState
    @Environment(\.scenePhase) private var scenePhase
    @State private var tabCustomizationPersistence = TabCustomizationPersistenceAdapter(
        scope: .guest,
        value: TabCustomizationStorage.load(for: .guest),
        persist: { context, customization in
            TabCustomizationStorage.save(customization, for: context.scope)
        },
        restore: { context in
            TabCustomizationStorage.load(for: context.scope)
        }
    )
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
        .alert(
            rootNoticePresentation.title,
            isPresented: rootNoticePresentation.isPresented
        ) {
            Button(NSLocalizedString("compose.error.ok", comment: "OK button"), role: .cancel) {
                rootNoticePresentation.dismiss()
            }
        } message: {
            Text(rootNoticePresentation.message)
        }
    }

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
                .badge(notificationReadState.presentation.badgeCount)

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
                    SearchView(
                        searchText: $searchText,
                        showingComposeView: $showingComposeView,
                        searchSubmitRequest: searchSubmitRequest,
                        routerSearchRequest: routerSearchRequest,
                        onRouterSearchRequestHandled: acknowledgeRouterSearchRequest
                    )
                    .searchable(text: $searchText)
                    .onSubmit(of: .search) {
                        submitSearch(query: searchText)
                    }
                    .textInputAutocapitalization(.never)
                }
                .accessibilityIdentifier("tab.search")
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
                    SearchView(
                        searchText: $searchText,
                        searchSubmitRequest: searchSubmitRequest,
                        routerSearchRequest: routerSearchRequest,
                        onRouterSearchRequestHandled: acknowledgeRouterSearchRequest
                    )
                    .searchable(text: $searchText)
                    .onSubmit(of: .search) {
                        submitSearch(query: searchText)
                    }
                    .textInputAutocapitalization(.never)
                }
                .accessibilityIdentifier("tab.search")
                .customizationID("search")

                Tab(NSLocalizedString("tab.signIn", comment: "Sign in tab"), systemImage: "rectangle.portrait.and.arrow.right", value: "signIn", role: nil) {
                    SignInView()
                }
                .accessibilityIdentifier("tab.sign-in")
                .customizationID("signIn")
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewCustomization(tabViewCustomizationBinding(for: tabCustomizationPersistence.activeContext))
        .task {
            synchronizeTabCustomizationScope(isAuthenticated: authManager.isAuthenticated)
            // Set default tab based on auth state
            if !applyRequestedTabIfAvailable(isAuthenticated: authManager.isAuthenticated) {
                selectedTab = AppTabSelectionPolicy.defaultTab(isAuthenticated: authManager.isAuthenticated).rawValue
                updateCurrentTab()
            }
            forwardRequestedSearch()
        }
        .task(id: notificationReadSession) {
            await refreshNotificationBadge()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await refreshNotificationBadge()
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            synchronizeTabCustomizationScope(isAuthenticated: isAuth)
            // Switch to appropriate tab when auth state changes
            if applyRequestedTabIfAvailable(isAuthenticated: isAuth) {
                return
            } else if migrateDeepLinkPathIfNeeded(isAuthenticated: isAuth) {
                return
            } else {
                selectedTab = AppTabSelectionPolicy.defaultTab(isAuthenticated: isAuth).rawValue
                updateCurrentTab()
            }
        }
        .onChange(of: selectedTab) { _, _ in
            updateCurrentTab()
        }
        .onChange(of: navigationCoordinator.currentTab) { _, tab in
            let normalizedTab = AppTabSelectionPolicy.normalized(
                tab,
                isAuthenticated: authManager.isAuthenticated
            )
            guard normalizedTab == tab else {
                navigationCoordinator.setCurrentTab(normalizedTab)
                return
            }
            guard selectedTab != normalizedTab.rawValue else { return }
            selectedTab = normalizedTab.rawValue
        }
        .onChange(of: navigationCoordinator.requestedSearch) { _, _ in
            forwardRequestedSearch()
        }
    }

    private func updateCurrentTab() {
        let tab = AppTabSelectionPolicy.normalized(
            AppTab(rawValue: selectedTab),
            isAuthenticated: authManager.isAuthenticated
        )
        guard navigationCoordinator.currentTab != tab else { return }
        navigationCoordinator.setCurrentTab(tab)
    }

    private var rootNoticePresentation: NavigationRootNoticePresentationAdapter {
        NavigationRootNoticePresentationAdapter(coordinator: navigationCoordinator)
    }

    private var notificationReadSession: NotificationReadSession? {
        currentNotificationReadSession(for: authManager)
    }

    private func refreshNotificationBadge() async {
        let session = notificationReadSession
        await notificationReadState.refreshUnreadCount(for: session)
    }

    private func forwardRequestedSearch() {
        ContentViewSearchRequestConsumer(navigationCoordinator: navigationCoordinator).consume(
            forward: { routerSearchRequest = $0 }
        )
    }

    private func acknowledgeRouterSearchRequest(_ request: SearchRequest) {
        guard routerSearchRequest?.id == request.id else { return }
        routerSearchRequest = nil
    }

    private func tabViewCustomizationBinding(
        for context: TabCustomizationPersistenceContext
    ) -> Binding<TabViewCustomization> {
        let capturedValue = tabCustomizationPersistence.value
        return Binding(
            get: {
                guard tabCustomizationPersistence.activeContext == context else {
                    return capturedValue
                }
                return tabCustomizationPersistence.value
            },
            set: { customization in
                tabCustomizationPersistence.apply(customization, from: context)
            }
        )
    }

    private func synchronizeTabCustomizationScope(isAuthenticated: Bool) {
        tabCustomizationPersistence.transition(
            to: TabCustomizationScope(isAuthenticated: isAuthenticated)
        )
    }

    private func submitSearch(query: String) {
        searchSubmitGeneration &+= 1
        searchSubmitRequest = SearchSubmitRequest(id: searchSubmitGeneration, query: query)
    }

    @discardableResult
    private func applyRequestedTabIfAvailable(isAuthenticated: Bool) -> Bool {
        guard navigationCoordinator.hasRequestedTab else { return false }

        let requestedTab = navigationCoordinator.currentTab
        navigationCoordinator.consumeRequestedTab()

        guard AppTabSelectionPolicy.isSelectable(requestedTab, isAuthenticated: isAuthenticated) else {
            return false
        }

        selectedTab = requestedTab.rawValue
        return true
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
        .environment(NotificationReadState())
        .environment(NavigationCoordinator())
        .environment(ExternalURLRouter.shared)
        .environmentObject(FontSettingsManager.shared)
    // swiftlint:disable:next file_length
}
