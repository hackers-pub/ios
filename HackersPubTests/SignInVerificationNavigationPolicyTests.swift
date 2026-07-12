@testable import HackersPub
import SwiftUI
import Testing

@MainActor
private final class DeepLinkAuthenticationSpy: DeepLinkAuthenticating {
    var isAuthenticated: Bool
    var sessionIdentity: AuthSessionIdentity
    private(set) var completionInvocationCount = 0
    private(set) var receivedExpectedSession: AuthSessionIdentity?
    private(set) var installedSessionIDs: [String] = []
    var sessionToInstallDuringCompletion: AuthSessionIdentity?

    init(isAuthenticated: Bool, sessionIdentity: AuthSessionIdentity) {
        self.isAuthenticated = isAuthenticated
        self.sessionIdentity = sessionIdentity
    }

    func completeLoginChallenge(
        token: String,
        code: String,
        expectedSession: AuthSessionIdentity
    ) async throws {
        completionInvocationCount += 1
        receivedExpectedSession = expectedSession

        let operations = SignInChallengeOperations(
            currentSession: { self.sessionIdentity },
            isAuthenticated: { self.isAuthenticated },
            performMutation: { _, _ in
                if let sessionToInstallDuringCompletion = self.sessionToInstallDuringCompletion {
                    await Task.yield()
                    self.sessionIdentity = sessionToInstallDuringCompletion
                    self.isAuthenticated = true
                }
                return "magic-link-session"
            },
            installSession: { sessionID in
                self.installedSessionIDs.append(sessionID)
                self.sessionIdentity = AuthSessionIdentity(
                    token: sessionID,
                    generation: self.sessionIdentity.generation &+ 1
                )
                self.isAuthenticated = true
            }
        )
        try await SignInChallengeCoordinator().complete(
            token: token,
            code: code,
            expectedSession: expectedSession,
            operations: operations
        )
    }
}

struct SignInVerificationNavigationPolicyTests {
    @Test func guestVerificationSelectsSignIn() {
        #expect(
            AppTabSelectionPolicy.signInVerificationDestination(
                isAuthenticated: false,
                currentTab: .local
            ) == .signIn
        )
    }

    @Test func authenticatedVerificationKeepsAValidCurrentTab() {
        #expect(
            AppTabSelectionPolicy.signInVerificationDestination(
                isAuthenticated: true,
                currentTab: .news
            ) == .news
        )
    }

    @Test func authenticatedVerificationReplacesAnInvalidCurrentTabWithTheDefault() {
        #expect(
            AppTabSelectionPolicy.signInVerificationDestination(
                isAuthenticated: true,
                currentTab: .signIn
            ) == .timeline
        )
    }

    @Test @MainActor func verificationFailurePersistsVisibleRootErrorUntilDismissed() {
        let coordinator = NavigationCoordinator()
        let presentation = NavigationRootNoticePresentationAdapter(coordinator: coordinator)

        coordinator.presentRootError(.signInVerificationFailed)

        #expect(presentation.notice == .signInVerificationFailed)
        #expect(presentation.isPresented.wrappedValue)
        #expect(!presentation.title.isEmpty)
        #expect(!presentation.message.isEmpty)

        presentation.isPresented.wrappedValue = false

        #expect(coordinator.rootError == nil)
    }

    @Test @MainActor func authenticatedDeepLinkDoesNotInvokeChallengeOrReplaceTheSession() {
        let existingSession = AuthSessionIdentity(token: "existing-session", generation: 7)
        let authentication = DeepLinkAuthenticationSpy(
            isAuthenticated: true,
            sessionIdentity: existingSession
        )
        let coordinator = NavigationCoordinator()
        coordinator.setCurrentTab(.news)

        let task = DeepLinkNavigator.open(
            .signInVerification(token: "stale-token", code: "stale-code"),
            authManager: authentication,
            navigationCoordinator: coordinator,
            externalURLRouter: .shared
        )

        #expect(task == nil)
        #expect(authentication.completionInvocationCount == 0)
        #expect(authentication.sessionIdentity == existingSession)
        #expect(coordinator.currentTab == .news)
        #expect(coordinator.rootError == .signInVerificationAlreadySignedIn)
        #expect(
            NavigationRootNoticePresentationAdapter(coordinator: coordinator)
                .isPresented.wrappedValue
        )
    }

    @Test @MainActor func guestChallengeInstallsSessionThroughProductionCoordinator() async {
        let guestSession = AuthSessionIdentity(token: nil, generation: 3)
        let authentication = DeepLinkAuthenticationSpy(
            isAuthenticated: false,
            sessionIdentity: guestSession
        )
        let coordinator = NavigationCoordinator()

        let task = DeepLinkNavigator.open(
            .signInVerification(token: "magic-token", code: "magic-code"),
            authManager: authentication,
            navigationCoordinator: coordinator,
            externalURLRouter: .shared
        )
        await task?.value

        #expect(authentication.completionInvocationCount == 1)
        #expect(authentication.receivedExpectedSession == guestSession)
        #expect(authentication.installedSessionIDs == ["magic-link-session"])
        #expect(authentication.sessionIdentity.token == "magic-link-session")
        #expect(coordinator.rootError == nil)
    }

    @Test @MainActor func sessionInstalledDuringChallengeCannotBeOverwrittenByTheDeepLink() async {
        let guestSession = AuthSessionIdentity(token: nil, generation: 3)
        let newerSession = AuthSessionIdentity(token: "passkey-session", generation: 4)
        let authentication = DeepLinkAuthenticationSpy(
            isAuthenticated: false,
            sessionIdentity: guestSession
        )
        authentication.sessionToInstallDuringCompletion = newerSession
        let coordinator = NavigationCoordinator()
        coordinator.setCurrentTab(.local)

        let task = DeepLinkNavigator.open(
            .signInVerification(token: "magic-token", code: "magic-code"),
            authManager: authentication,
            navigationCoordinator: coordinator,
            externalURLRouter: .shared
        )
        await task?.value

        #expect(authentication.completionInvocationCount == 1)
        #expect(authentication.receivedExpectedSession == guestSession)
        #expect(authentication.sessionIdentity == newerSession)
        #expect(authentication.installedSessionIDs.isEmpty)
        #expect(coordinator.rootError == .signInVerificationSessionChanged)
    }

    @Test func sessionGenerationRejectsAnOlderGuestChallengeAfterAnABASessionChange() {
        let expectedGuest = AuthSessionIdentity(token: nil, generation: 1)
        let currentGuest = AuthSessionIdentity(token: nil, generation: 3)

        #expect(
            !expectedGuest.permitsChallengeMutation(
                current: currentGuest,
                isAuthenticated: false
            )
        )
    }
}
