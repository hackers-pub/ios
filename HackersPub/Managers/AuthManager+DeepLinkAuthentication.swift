@preconcurrency import Apollo
import Foundation

extension AuthManager: DeepLinkAuthenticating {
    func completeLoginChallenge(
        token: String,
        code: String,
        expectedSession: AuthSessionIdentity
    ) async throws {
        let operations = SignInChallengeOperations(
            currentSession: { self.sessionIdentity },
            isAuthenticated: { self.isAuthenticated },
            performMutation: { token, code in
                try await self.performLoginChallengeMutation(token: token, code: code)
            },
            installSession: { sessionID in
                try await self.persistAndInstallSession(sessionID)
            }
        )
        try await SignInChallengeCoordinator().complete(
            token: token,
            code: code,
            expectedSession: expectedSession,
            operations: operations
        )
    }

    private func performLoginChallengeMutation(
        token: String,
        code: String
    ) async throws -> String {
        let response: GraphQLResponse<HackersPub.CompleteLoginChallengeMutation>
        do {
            response = try await client.perform(
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

        return session.id
    }
}
