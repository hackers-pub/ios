// The session lifecycle is intentionally co-located so ownership checks remain auditable.
// swiftlint:disable file_length
@preconcurrency import Apollo
import ApolloAPI
import Foundation
import UIKit

enum AuthSessionInvalidationPolicy {
    static func shouldClearLocalSession(
        hasResponseData: Bool,
        viewerIsNil: Bool,
        graphQLErrorsPresent: Bool,
        httpStatusCode: Int?
    ) -> Bool {
        if let httpStatusCode {
            return httpStatusCode == 401 || httpStatusCode == 403
        }

        return hasResponseData && viewerIsNil && !graphQLErrorsPresent
    }
}

struct PasskeyInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let created: String
    let lastUsed: String?
}

struct PasskeyPage: Equatable {
    let passkeys: [PasskeyInfo]
    let hasNextPage: Bool
    let endCursor: String?
}

typealias PasskeyPageLoader = @MainActor (String?) async throws -> PasskeyPage

enum PasskeyPaginationResult: Equatable {
    case loaded([PasskeyInfo])
    case discardedForSessionChange
}

enum PasskeyPaginationError: LocalizedError, Equatable {
    case missingConnection
    case missingEndCursor
    case nonProgressingCursor
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingConnection, .missingEndCursor, .nonProgressingCursor:
            return NSLocalizedString("passkey.error.failed", comment: "Passkey operation failed error")
        case let .requestFailed(message):
            return message
        }
    }
}

@MainActor
func loadAllPasskeys(
    expectedSessionToken: String,
    currentSessionToken: () -> String?,
    fetchPage: (String?) async throws -> PasskeyPage
) async throws -> PasskeyPaginationResult {
    var allPasskeys: [PasskeyInfo] = []
    var seenPasskeyIDs: Set<String> = []
    var visitedCursors: Set<String> = []
    var cursor: String?

    while true {
        try Task.checkCancellation()
        guard currentSessionToken() == expectedSessionToken else {
            return .discardedForSessionChange
        }
        let page = try await fetchPage(cursor)
        try Task.checkCancellation()
        guard currentSessionToken() == expectedSessionToken else {
            return .discardedForSessionChange
        }
        for passkey in page.passkeys where seenPasskeyIDs.insert(passkey.id).inserted {
            allPasskeys.append(passkey)
        }
        guard page.hasNextPage else { return .loaded(allPasskeys) }
        guard let endCursor = page.endCursor,
              !endCursor.isEmpty,
              endCursor != cursor,
              visitedCursors.insert(endCursor).inserted
        else {
            throw page.endCursor == nil
                ? PasskeyPaginationError.missingEndCursor
                : PasskeyPaginationError.nonProgressingCursor
        }
        cursor = endCursor
    }
}

struct PasskeyListRequestContext {
    let id: UUID
    let sessionToken: String?
}

@Observable
@MainActor
// Splitting this lifecycle across files would obscure ordering-sensitive ownership guards.
// swiftlint:disable:next type_body_length
class AuthManager {
    static let shared = AuthManager()
    static let passkeyPageSize: Int32 = 50

    let client: ApolloClient
    let passkeyAuthorizer: any PasskeyAuthorizing
    private let sessionCredentialStore: any SessionCredentialStore
    private let sessionInvalidationStore: any SessionInvalidationStore
    private let credentialOperationLane = SessionCredentialOperationLane()

    private(set) var sessionToken: String?
    private(set) var currentAccount: HackersPub.ViewerQuery.Data.Viewer?
    private(set) var passkeys: [PasskeyInfo] = []
    private(set) var passkeysLoadError: String?
    private(set) var passkeyListLoadState: PasskeyListLoadState = .idle
    var isLoadingPasskeys: Bool {
        passkeyListLoadState == .loading
    }

    private var activePasskeyListRequestID: UUID?
    var passkeyPageLoader: PasskeyPageLoader?
    private(set) var sessionGeneration: UInt64 = 0
    private(set) var isAuthenticated = false
    private(set) var isLoading = true
    private var needsProtectedDataRetry = false

    private convenience init() {
        self.init(
            client: apolloClient,
            sessionCredentialStore: KeychainHelper.shared,
            sessionInvalidationStore: UserDefaultsSessionInvalidationStore.shared
        )
        observeProtectedDataAvailability()
        Task {
            await loadSession()
        }
    }

    init(
        client: ApolloClient,
        sessionCredentialStore: any SessionCredentialStore,
        sessionInvalidationStore: any SessionInvalidationStore,
        passkeyAuthorizer: any PasskeyAuthorizing = PasskeyService.shared
    ) {
        self.client = client
        self.passkeyAuthorizer = passkeyAuthorizer
        self.sessionCredentialStore = sessionCredentialStore
        self.sessionInvalidationStore = sessionInvalidationStore
    }

    init(
        authenticatedSessionToken: String,
        initialPasskeys: [PasskeyInfo] = [],
        passkeyPageLoader: @escaping PasskeyPageLoader
    ) {
        client = apolloClient
        passkeyAuthorizer = PasskeyService.shared
        sessionCredentialStore = KeychainHelper.shared
        sessionInvalidationStore = UserDefaultsSessionInvalidationStore.shared
        sessionToken = authenticatedSessionToken
        passkeys = initialPasskeys
        self.passkeyPageLoader = passkeyPageLoader
        isAuthenticated = true
        isLoading = false
    }

    // This state machine preserves the ordering of credential and invalidation cleanup.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func loadSession() async {
        let identityAtStart = sessionIdentity
        isLoading = true
        defer { isLoading = false }

        #if DEBUG
            if UITestLaunchConfiguration.forcesGuestSession {
                applyLoggedOutState()
                return
            }
        #endif

        let pendingMarker = await sessionInvalidationStore.pendingMarker()
        guard ownsSessionIdentity(identityAtStart) else { return }

        // Try to load token from keychain
        do {
            let token = try await sessionCredentialStore.get(key: "sessionToken")
            guard ownsSessionIdentity(identityAtStart) else { return }

            if var pendingMarker {
                if pendingMarker.isLegacy {
                    let upgradedMarker = SessionInvalidationMarker(token: token)
                    await sessionInvalidationStore.markPending(upgradedMarker)
                    guard ownsSessionIdentity(identityAtStart) else {
                        await sessionInvalidationStore.clearPending(upgradedMarker)
                        return
                    }
                    pendingMarker = upgradedMarker
                }

                if pendingMarker.matches(token: token) {
                    _ = await finishPendingSessionInvalidation(
                        marker: pendingMarker,
                        expectedIdentity: AuthSessionIdentity(
                            token: token,
                            generation: identityAtStart.generation
                        )
                    )
                    return
                }

                await sessionInvalidationStore.clearPending(pendingMarker)
                guard ownsSessionIdentity(identityAtStart) else { return }
            }

            needsProtectedDataRetry = false

            if let token {
                installSessionToken(token)

                // Try to verify the session by fetching viewer
                // If this fails due to network, we'll stay authenticated
                await fetchViewer()
            }
        } catch let error as KeychainError where error.isProtectedDataUnavailable {
            guard ownsSessionIdentity(identityAtStart) else { return }
            needsProtectedDataRetry = true
            #if DEBUG
                NSLog("Session keychain data is unavailable until protected data becomes active")
            #endif
        } catch {
            guard ownsSessionIdentity(identityAtStart) else { return }
            needsProtectedDataRetry = false
            #if DEBUG
                NSLog("Error loading session: \(String(describing: error))")
            #endif
        }
    }

    func fetchViewer() async {
        await fetchViewer(expectedIdentity: sessionIdentity)
    }

    private func fetchViewer(expectedIdentity: AuthSessionIdentity) async {
        guard ownsSessionIdentity(expectedIdentity) else { return }
        guard sessionToken != nil else {
            isAuthenticated = false
            currentAccount = nil
            return
        }

        do {
            let response = try await client.fetch(
                query: HackersPub.ViewerQuery(),
                cachePolicy: .networkOnly
            )
            guard ownsSessionIdentity(expectedIdentity) else { return }
            let graphQLErrorsPresent = !(response.errors?.isEmpty ?? true)
            let viewer = response.data?.viewer

            if AuthSessionInvalidationPolicy.shouldClearLocalSession(
                hasResponseData: response.data != nil,
                viewerIsNil: viewer == nil,
                graphQLErrorsPresent: graphQLErrorsPresent,
                httpStatusCode: nil
            ) {
                await invalidateLocalSession(expectedIdentity: expectedIdentity)
                return
            }

            if let viewer {
                currentAccount = viewer
                isAuthenticated = true
            } else {
                // Partial/malformed GraphQL data is not proof that the credential expired.
                isAuthenticated = sessionToken != nil
            }
        } catch {
            guard ownsSessionIdentity(expectedIdentity) else { return }
            let httpStatusCode = (error as? ResponseCodeInterceptor.ResponseCodeError)?.response.statusCode
            if AuthSessionInvalidationPolicy.shouldClearLocalSession(
                hasResponseData: false,
                viewerIsNil: false,
                graphQLErrorsPresent: false,
                httpStatusCode: httpStatusCode
            ) {
                await invalidateLocalSession(expectedIdentity: expectedIdentity)
                return
            }

            #if DEBUG
                NSLog("Viewer fetch failed without an authentication status: \(String(describing: error))")
            #endif
            // Preserve a known local session for a later retry or offline cache access.
            isAuthenticated = sessionToken != nil
        }
    }

    func signOut() async {
        let identityAtStart = reserveSessionReplacement()
        // Try to revoke the session on the server
        if let token = identityAtStart.token {
            do {
                _ = try await client.perform(
                    mutation: HackersPub.RevokeSessionMutation(sessionId: token)
                )
            } catch {
                // Even if revocation fails, we still clear local state
                print("Error revoking session: \(error)")
            }
        }

        await invalidateLocalSession(expectedIdentity: identityAtStart)
    }

    func invalidateLocalSession() async {
        await invalidateLocalSession(expectedIdentity: sessionIdentity)
    }

    func invalidateLocalSession(expectedIdentity: AuthSessionIdentity) async {
        guard ownsSessionIdentity(expectedIdentity) else { return }
        let marker = SessionInvalidationMarker(token: expectedIdentity.token)
        await sessionInvalidationStore.markPending(marker)
        guard ownsSessionIdentity(expectedIdentity) else {
            await sessionInvalidationStore.clearPending(marker)
            return
        }

        guard await finishPendingSessionInvalidation(
            marker: marker,
            expectedIdentity: expectedIdentity
        )
        else {
            return
        }

        do {
            try await client.clearCache()
        } catch {
            #if DEBUG
                NSLog("Error clearing Apollo cache: \(String(describing: error))")
            #endif
        }
    }

    private func applyLoggedOutState() {
        needsProtectedDataRetry = false
        sessionGeneration &+= 1
        sessionToken = nil
        currentAccount = nil
        passkeys = []
        passkeysLoadError = nil
        activePasskeyListRequestID = nil
        passkeyListLoadState.finishLoading()
        isAuthenticated = false
    }

    private func finishPendingSessionInvalidation(
        marker: SessionInvalidationMarker,
        expectedIdentity: AuthSessionIdentity
    ) async -> Bool {
        guard ownsSessionGeneration(expectedIdentity) else { return false }
        let activeMarker = await sessionInvalidationStore.pendingMarker()
        guard ownsSessionGeneration(expectedIdentity), activeMarker == marker else { return false }

        applyLoggedOutState()
        let cleanupIdentity = sessionIdentity
        do {
            if let token = expectedIdentity.token {
                try await discardPersistedSession(matching: token)
            }
            guard ownsSessionIdentity(cleanupIdentity) else { return false }
            await sessionInvalidationStore.clearPending(marker)
            guard ownsSessionIdentity(cleanupIdentity) else { return false }
            needsProtectedDataRetry = false
            return true
        } catch let error as KeychainError where error.isProtectedDataUnavailable {
            guard ownsSessionIdentity(cleanupIdentity) else { return false }
            needsProtectedDataRetry = true
            #if DEBUG
                NSLog("Session invalidation cleanup is waiting for protected data")
            #endif
            return true
        } catch {
            guard ownsSessionIdentity(cleanupIdentity) else { return false }
            needsProtectedDataRetry = false
            #if DEBUG
                NSLog("Session invalidation cleanup failed: \(String(describing: error))")
            #endif
            return true
        }
    }

    func persistAndInstallSession(_ id: String) async throws {
        let replacementIdentity = reserveSessionReplacement()
        guard try await persistSession(id, expectedIdentity: replacementIdentity) else { return }
        let markerToClear = await sessionInvalidationStore.pendingMarker()
        guard ownsSessionIdentity(replacementIdentity) else {
            try await discardPersistedSession(matching: id)
            return
        }
        if let markerToClear {
            await sessionInvalidationStore.clearPending(markerToClear)
        }
        guard ownsSessionIdentity(replacementIdentity) else {
            try await discardPersistedSession(matching: id)
            return
        }
        installSessionToken(id)
        await fetchViewer()
    }

    private func persistSession(
        _ token: String,
        expectedIdentity: AuthSessionIdentity
    ) async throws -> Bool {
        await credentialOperationLane.enter()
        do {
            try await sessionCredentialStore.save(key: "sessionToken", value: token)
            guard ownsSessionIdentity(expectedIdentity) else {
                _ = try await sessionCredentialStore.delete(
                    key: "sessionToken",
                    matchingValue: token
                )
                await credentialOperationLane.leave()
                return false
            }
            await credentialOperationLane.leave()
            return true
        } catch {
            await credentialOperationLane.leave()
            throw error
        }
    }

    private func discardPersistedSession(matching token: String) async throws {
        await credentialOperationLane.enter()
        do {
            _ = try await sessionCredentialStore.delete(
                key: "sessionToken",
                matchingValue: token
            )
            await credentialOperationLane.leave()
        } catch {
            await credentialOperationLane.leave()
            throw error
        }
    }

    var sessionIdentity: AuthSessionIdentity {
        AuthSessionIdentity(token: sessionToken, generation: sessionGeneration)
    }

    private func ownsSessionIdentity(_ identity: AuthSessionIdentity) -> Bool {
        sessionIdentity == identity
    }

    private func ownsSessionGeneration(_ identity: AuthSessionIdentity) -> Bool {
        sessionGeneration == identity.generation
    }

    private func installSessionToken(_ token: String) {
        needsProtectedDataRetry = false
        sessionGeneration &+= 1
        sessionToken = token
        // A persisted credential is usable offline while viewer verification is pending.
        isAuthenticated = true
    }

    private func reserveSessionReplacement() -> AuthSessionIdentity {
        precondition(sessionGeneration < UInt64.max, "Session generation exhausted")
        sessionGeneration += 1
        return sessionIdentity
    }

    func removePasskeyFromList(id: String) {
        passkeys.removeAll { $0.id == id }
    }

    func beginPasskeyListRequest() -> PasskeyListRequestContext? {
        guard isAuthenticated else {
            activePasskeyListRequestID = nil
            passkeys = []
            passkeysLoadError = nil
            passkeyListLoadState.finishLoading()
            return nil
        }
        passkeysLoadError = nil
        passkeyListLoadState.beginLoading()
        let context = PasskeyListRequestContext(id: UUID(), sessionToken: sessionToken)
        activePasskeyListRequestID = context.id
        return context
    }

    func completePasskeyListRequest(
        _ loadedPasskeys: [PasskeyInfo],
        context: PasskeyListRequestContext
    ) {
        guard ownsPasskeyListRequest(context), !Task.isCancelled else {
            finishPasskeyListRequest(context: context)
            return
        }
        passkeys = loadedPasskeys
        finishPasskeyListRequest(context: context)
    }

    func failPasskeyListRequest(error: any Error, context: PasskeyListRequestContext) {
        guard activePasskeyListRequestID == context.id else { return }
        guard !Task.isCancelled,
              isAuthenticated,
              sessionToken == context.sessionToken
        else {
            finishPasskeyListRequest(context: context)
            return
        }
        activePasskeyListRequestID = nil
        passkeyListLoadState.fail()
        passkeysLoadError = NSLocalizedString(
            "settings.passkeys.loadFailed",
            comment: "Passkey list load failure"
        )
        #if DEBUG
            NSLog("Error loading passkeys: \(String(describing: error))")
        #endif
    }

    func finishPasskeyListRequest(context: PasskeyListRequestContext) {
        guard activePasskeyListRequestID == context.id else { return }
        activePasskeyListRequestID = nil
        passkeyListLoadState.finishLoading()
    }

    private func ownsPasskeyListRequest(_ context: PasskeyListRequestContext) -> Bool {
        activePasskeyListRequestID == context.id &&
            isAuthenticated &&
            sessionToken == context.sessionToken
    }
}

private extension AuthManager {
    func observeProtectedDataAvailability() {
        let notificationCenter = NotificationCenter.default
        let retry: @Sendable (Notification) -> Void = { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.retryPendingSessionLoad()
            }
        }
        notificationCenter.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil,
            queue: .main,
            using: retry
        )
        notificationCenter.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main,
            using: retry
        )
    }

    func retryPendingSessionLoad() async {
        guard !isLoading else {
            return
        }

        if await sessionInvalidationStore.pendingMarker() != nil {
            guard UIApplication.shared.isProtectedDataAvailable else { return }
            await loadSession()
            return
        }

        guard needsProtectedDataRetry,
              UIApplication.shared.isProtectedDataAvailable
        else { return }
        await loadSession()
    }
}

// swiftlint:enable file_length
