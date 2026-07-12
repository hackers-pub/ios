import Foundation

@MainActor
enum DeepLinkNavigator {
    @MainActor
    struct URLDependencies {
        let openFallback: (URL) -> Void

        static func live(externalURLRouter: ExternalURLRouter) -> Self {
            Self(openFallback: { url in
                DeepLinkNavigator.openFallbackURL(
                    url,
                    externalURLRouter: externalURLRouter
                )
            })
        }
    }

    @MainActor
    struct PostDependencies {
        let resolvePostID: (String) async throws -> String?
        let openFallback: (String) -> Void

        static func live(externalURLRouter: ExternalURLRouter) -> Self {
            Self(
                resolvePostID: { urlString in
                    try await DeepLinkPostResolver.resolvePostID(for: urlString)
                },
                openFallback: { urlString in
                    DeepLinkNavigator.openFallbackURL(
                        urlString,
                        externalURLRouter: externalURLRouter
                    )
                }
            )
        }
    }

    @discardableResult
    static func open(
        _ url: URL,
        authManager: any DeepLinkAuthenticating,
        navigationCoordinator: NavigationCoordinator,
        externalURLRouter: ExternalURLRouter,
        urlDependencies: URLDependencies? = nil
    ) -> Task<Void, Never>? {
        guard let route = HackersPubURLRouter.resolve(url) else {
            guard isWebFallbackURL(url) else { return nil }
            let dependencies = urlDependencies ?? .live(
                externalURLRouter: externalURLRouter
            )
            dependencies.openFallback(url)
            return nil
        }

        return open(
            route,
            authManager: authManager,
            navigationCoordinator: navigationCoordinator,
            externalURLRouter: externalURLRouter
        )
    }

    @discardableResult
    static func open(
        _ route: HackersPubDeepLinkRoute,
        authManager: any DeepLinkAuthenticating,
        navigationCoordinator: NavigationCoordinator,
        externalURLRouter: ExternalURLRouter,
        postDependencies: PostDependencies? = nil
    ) -> Task<Void, Never>? {
        switch route {
        case let .profile(handle):
            openProfile(
                handle,
                authManager: authManager,
                navigationCoordinator: navigationCoordinator
            )
            return nil
        case let .postURL(urlString):
            return openPost(
                urlString,
                authManager: authManager,
                navigationCoordinator: navigationCoordinator,
                externalURLRouter: externalURLRouter,
                dependencies: postDependencies
            )
        case let .newsStory(id):
            navigationCoordinator.navigateToNewsStory(id: id)
            return nil
        case let .signInVerification(token, code):
            return openSignInVerification(
                token: token,
                code: code,
                authManager: authManager,
                navigationCoordinator: navigationCoordinator
            )
        case let .tagSearch(tag):
            navigationCoordinator.openSearch(query: tag)
            return nil
        }
    }

    private static func openProfile(
        _ handle: String,
        authManager: any DeepLinkAuthenticating,
        navigationCoordinator: NavigationCoordinator
    ) {
        navigationCoordinator.navigateToProfile(
            handle: handle,
            on: authManager.isAuthenticated ? .timeline : .local
        )
    }

    private static func openPost(
        _ urlString: String,
        authManager: any DeepLinkAuthenticating,
        navigationCoordinator: NavigationCoordinator,
        externalURLRouter: ExternalURLRouter,
        dependencies: PostDependencies?
    ) -> Task<Void, Never> {
        let initialTab = AppTabSelectionPolicy.defaultTab(
            isAuthenticated: authManager.isAuthenticated
        )
        let dependencies = dependencies ?? .live(externalURLRouter: externalURLRouter)
        let routeGeneration = navigationCoordinator.beginPostRoute()
        navigationCoordinator.setCurrentTab(initialTab, requested: true)

        let task = Task {
            await Task.yield()
            guard navigationCoordinator.ownsPostRoute(routeGeneration) else { return }
            defer { navigationCoordinator.finishPostRoute(routeGeneration) }

            do {
                if let postID = try await dependencies.resolvePostID(urlString) {
                    await MainActor.run {
                        guard
                            !Task.isCancelled,
                            navigationCoordinator.ownsPostRoute(routeGeneration)
                        else { return }
                        let destination = AppTabSelectionPolicy.normalized(
                            navigationCoordinator.currentTab,
                            isAuthenticated: authManager.isAuthenticated
                        )
                        navigationCoordinator.navigateToPost(id: postID, on: destination)
                    }
                } else {
                    guard
                        !Task.isCancelled,
                        navigationCoordinator.ownsPostRoute(routeGeneration)
                    else { return }
                    dependencies.openFallback(urlString)
                }
            } catch is CancellationError {
                return
            } catch {
                print("Error resolving post URL: \(error)")
                guard
                    !Task.isCancelled,
                    navigationCoordinator.ownsPostRoute(routeGeneration)
                else { return }
                dependencies.openFallback(urlString)
            }
        }
        navigationCoordinator.retainPostRouteTask(task, for: routeGeneration)
        return task
    }

    private static func openSignInVerification(
        token: String,
        code: String,
        authManager: any DeepLinkAuthenticating,
        navigationCoordinator: NavigationCoordinator
    ) -> Task<Void, Never>? {
        let expectedSession = authManager.sessionIdentity
        let destination = AppTabSelectionPolicy.signInVerificationDestination(
            isAuthenticated: authManager.isAuthenticated,
            currentTab: navigationCoordinator.currentTab
        )
        navigationCoordinator.setCurrentTab(destination, requested: true)

        guard expectedSession.permitsChallengeMutation(
            current: authManager.sessionIdentity,
            isAuthenticated: authManager.isAuthenticated
        ) else {
            navigationCoordinator.presentRootError(.signInVerificationAlreadySignedIn)
            return nil
        }

        return Task {
            do {
                try await authManager.completeLoginChallenge(
                    token: token,
                    code: code,
                    expectedSession: expectedSession
                )
                await MainActor.run {
                    let destination = AppTabSelectionPolicy.signInVerificationDestination(
                        isAuthenticated: authManager.isAuthenticated,
                        currentTab: navigationCoordinator.currentTab
                    )
                    navigationCoordinator.setCurrentTab(destination, requested: true)
                }
            } catch AuthError.sessionChanged {
                await MainActor.run {
                    navigationCoordinator.presentRootError(.signInVerificationSessionChanged)
                }
            } catch {
                await MainActor.run {
                    navigationCoordinator.presentRootError(.signInVerificationFailed)
                }
            }
        }
    }

    private static func openFallbackURL(
        _ urlString: String,
        externalURLRouter: ExternalURLRouter
    ) {
        guard let url = URL(string: urlString) else { return }
        openFallbackURL(url, externalURLRouter: externalURLRouter)
    }

    private static func openFallbackURL(
        _ url: URL,
        externalURLRouter: ExternalURLRouter
    ) {
        guard isWebFallbackURL(url) else { return }

        if HackersPubURLRouter.isHackersPubWebURL(url) {
            externalURLRouter.openInApp(url)
        } else {
            externalURLRouter.open(url)
        }
    }

    private static func isWebFallbackURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https"].contains(scheme)
    }
}
