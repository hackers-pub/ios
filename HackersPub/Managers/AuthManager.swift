import Foundation
@preconcurrency import Apollo
import ApolloAPI

struct PasskeyInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let created: String
    let lastUsed: String?
}

@Observable
@MainActor
class AuthManager {
    static let shared = AuthManager()

    private(set) var sessionToken: String?
    private(set) var currentAccount: HackersPub.ViewerQuery.Data.Viewer?
    private(set) var passkeys: [PasskeyInfo] = []
    private(set) var isLoadingPasskeys = false
    private(set) var isAuthenticated = false
    private(set) var isLoading = true

    private init() {
        Task {
            await loadSession()
        }
    }

    func loadSession() async {
        isLoading = true
        defer { isLoading = false }

        // Try to load token from keychain
        do {
            if let token = try await KeychainHelper.shared.get(key: "sessionToken") {
                sessionToken = token

                // Immediately mark as authenticated since we have a valid token
                // This allows offline access to cached data
                isAuthenticated = true

                // Try to verify the session by fetching viewer
                // If this fails due to network, we'll stay authenticated
                await fetchViewer()
            }
        } catch {
            print("Error loading session: \(error)")
        }
    }

    func fetchViewer() async {
        guard sessionToken != nil else {
            isAuthenticated = false
            currentAccount = nil
            return
        }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.ViewerQuery(),
                cachePolicy: .networkOnly
            )
            currentAccount = response.data?.viewer
            isAuthenticated = currentAccount != nil
        } catch {
            print("Error fetching viewer: \(error)")

            // Check if this is an authentication error
            var isAuthError = false

            // Check for HTTP status codes in the error
            if let nsError = error as NSError? {
                // Check for 401 or 403 in error code or userInfo
                if nsError.code == 401 || nsError.code == 403 {
                    isAuthError = true
                }
            }

            // Also check error description for auth-related strings
            if !isAuthError {
                let errorString = error.localizedDescription.lowercased()
                isAuthError = errorString.contains("401") ||
                             errorString.contains("403") ||
                             errorString.contains("unauthorized") ||
                             errorString.contains("forbidden") ||
                             errorString.contains("not authenticated")
            }

            if isAuthError {
                print("Authentication error detected, signing out")
                await signOut()
            } else {
                print("Network or server error, keeping user signed in")
                // Keep user authenticated if we have a session token
                // They will be able to use cached data offline
                isAuthenticated = sessionToken != nil
                // Try to load cached viewer data if available
                if currentAccount == nil {
                    // We'll stay authenticated but without account details
                    // The UI should handle this gracefully
                    print("No cached viewer data available, but keeping session active")
                }
            }
        }
    }

    func loginByUsername(username: String, verifyUrl: String, locale: String? = nil) async throws -> String {
        let effectiveLocale = locale ?? Locale.current.language.languageCode?.identifier ?? "en"
        let response = try await apolloClient.perform(
            mutation: HackersPub.LoginByUsernameMutation(
                username: username,
                locale: effectiveLocale,
                verifyUrl: verifyUrl
            )
        )

        guard let loginResult = response.data?.loginByUsername else {
            throw AuthError.loginFailed
        }

        if let challenge = loginResult.asLoginChallenge {
            return challenge.token
        } else if loginResult.asAccountNotFoundError != nil {
            throw AuthError.accountNotFound
        } else {
            throw AuthError.loginFailed
        }
    }

    func completeLoginChallenge(token: String, code: String) async throws {
        let response: GraphQLResponse<HackersPub.CompleteLoginChallengeMutation>
        do {
            response = try await apolloClient.perform(
                mutation: HackersPub.CompleteLoginChallengeMutation(
                    token: token,
                    code: code
                )
            )
        } catch {
            #if DEBUG
            NSLog("CompleteLoginChallenge transport/client error: \(String(describing: error))")
            #endif
            throw error
        }

        #if DEBUG
        if let errors = response.errors, !errors.isEmpty {
            for error in errors {
                NSLog("CompleteLoginChallenge GraphQL error: \(error.message ?? "<no message>")")
            }
        }
        #endif

        guard let session = response.data?.completeLoginChallenge else {
            #if DEBUG
            NSLog("CompleteLoginChallenge returned no session data")
            #endif
            throw AuthError.verificationFailed
        }

        // Store session token
        sessionToken = session.id
        try await KeychainHelper.shared.save(key: "sessionToken", value: session.id)

        // Fetch current user
        await fetchViewer()
    }

    func signInWithPasskey() async throws {
        let sessionId = UUID().uuidString
        let optionsResponse = try await apolloClient.perform(
            mutation: HackersPub.GetPasskeyAuthenticationOptionsMutation(sessionId: sessionId)
        )
        guard let optionsJSON = optionsResponse.data?.getPasskeyAuthenticationOptions else {
            throw AuthError.passkeyFailed
        }

        let options = try PasskeyAuthenticationOptions(json: optionsJSON)
        let authenticationResponse = try await PasskeyService.shared.authenticate(options: options)
        let loginResponse = try await apolloClient.perform(
            mutation: HackersPub.LoginByPasskeyMutation(
                sessionId: sessionId,
                authenticationResponse: authenticationResponse
            )
        )

        guard let session = loginResponse.data?.loginByPasskey else {
            throw AuthError.passkeyFailed
        }

        sessionToken = session.id
        try await KeychainHelper.shared.save(key: "sessionToken", value: session.id)
        await fetchViewer()
    }

    func loadPasskeys() async {
        guard isAuthenticated else {
            passkeys = []
            return
        }

        isLoadingPasskeys = true
        defer { isLoadingPasskeys = false }
        let requestToken = sessionToken

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.ViewerPasskeysQuery(),
                cachePolicy: .networkOnly
            )
            guard isAuthenticated, sessionToken == requestToken else { return }
            passkeys = response.data?.viewer?.passkeys.edges.map {
                PasskeyInfo(
                    id: $0.node.id,
                    name: $0.node.name,
                    created: $0.node.created,
                    lastUsed: $0.node.lastUsed
                )
            } ?? []
        } catch {
            print("Error loading passkeys: \(error)")
        }
    }

    func registerPasskey(name: String) async throws {
        if currentAccount == nil {
            await fetchViewer()
        }
        guard let accountId = currentAccount?.id else {
            throw AuthError.passkeyFailed
        }

        let optionsResponse = try await apolloClient.perform(
            mutation: HackersPub.GetPasskeyRegistrationOptionsMutation(accountId: accountId)
        )
        guard let optionsJSON = optionsResponse.data?.getPasskeyRegistrationOptions else {
            throw AuthError.passkeyFailed
        }

        let options = try PasskeyRegistrationOptions(json: optionsJSON)
        let registrationResponse = try await PasskeyService.shared.register(options: options)
        let response = try await apolloClient.perform(
            mutation: HackersPub.VerifyPasskeyRegistrationMutation(
                accountId: accountId,
                name: name,
                registrationResponse: registrationResponse
            )
        )

        guard response.data?.verifyPasskeyRegistration.verified == true else {
            throw AuthError.passkeyFailed
        }

        await loadPasskeys()
    }

    func revokePasskey(id: String) async throws {
        let response = try await apolloClient.perform(
            mutation: HackersPub.RevokePasskeyMutation(passkeyId: id)
        )
        guard response.data?.revokePasskey == id else {
            throw AuthError.passkeyFailed
        }
        passkeys.removeAll { $0.id == id }
    }

    func signOut() async {
        // Try to revoke the session on the server
        if let token = sessionToken {
            do {
                _ = try await apolloClient.perform(
                    mutation: HackersPub.RevokeSessionMutation(sessionId: token)
                )
            } catch {
                // Even if revocation fails, we still clear local state
                print("Error revoking session: \(error)")
            }
        }

        // Clear local state
        sessionToken = nil
        currentAccount = nil
        passkeys = []
        isAuthenticated = false

        // Clear from keychain
        try? await KeychainHelper.shared.delete(key: "sessionToken")

        do {
            try await apolloClient.clearCache()
        } catch {
            print("Error clearing Apollo cache: \(error)")
        }
    }
}

enum AuthError: LocalizedError {
    case loginFailed
    case accountNotFound
    case verificationFailed
    case passkeyFailed

    var errorDescription: String? {
        switch self {
        case .loginFailed:
            return "Login failed. Please try again."
        case .accountNotFound:
            return "Account not found. Please check your username."
        case .verificationFailed:
            return "Verification failed. Please check your code."
        case .passkeyFailed:
            return NSLocalizedString("passkey.error.failed", comment: "Passkey operation failed error")
        }
    }
}
