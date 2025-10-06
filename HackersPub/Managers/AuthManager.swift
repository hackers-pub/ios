import Foundation
@preconcurrency import Apollo

@Observable
@MainActor
class AuthManager {
    static let shared = AuthManager()

    private(set) var sessionToken: String?
    private(set) var currentAccount: HackersPub.ViewerQuery.Data.Viewer?
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

                // Verify the session by fetching viewer
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
            // Clear cache first to ensure fresh data
            try await apolloClient.clearCache()
            let response = try await apolloClient.fetch(query: HackersPub.ViewerQuery())
            currentAccount = response.data?.viewer
            isAuthenticated = currentAccount != nil
        } catch {
            print("Error fetching viewer: \(error)")
            // Session is invalid, clear it
            await signOut()
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
        let response = try await apolloClient.perform(
            mutation: HackersPub.CompleteLoginChallengeMutation(
                token: token,
                code: code
            )
        )

        guard let session = response.data?.completeLoginChallenge else {
            throw AuthError.verificationFailed
        }

        // Store session token
        sessionToken = session.id
        try await KeychainHelper.shared.save(key: "sessionToken", value: session.id)

        // Fetch current user
        await fetchViewer()
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
        isAuthenticated = false

        // Clear from keychain
        try? await KeychainHelper.shared.delete(key: "sessionToken")
    }
}

enum AuthError: LocalizedError {
    case loginFailed
    case accountNotFound
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .loginFailed:
            return "Login failed. Please try again."
        case .accountNotFound:
            return "Account not found. Please check your username."
        case .verificationFailed:
            return "Verification failed. Please check your code."
        }
    }
}
