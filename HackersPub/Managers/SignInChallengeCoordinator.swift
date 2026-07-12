@MainActor
struct SignInChallengeOperations {
    let currentSession: () -> AuthSessionIdentity
    let isAuthenticated: () -> Bool
    let performMutation: (String, String) async throws -> String
    let installSession: (String) async throws -> Void
}

@MainActor
struct SignInChallengeCoordinator {
    func complete(
        token: String,
        code: String,
        expectedSession: AuthSessionIdentity,
        operations: SignInChallengeOperations
    ) async throws {
        try validate(expectedSession: expectedSession, operations: operations)
        let sessionID = try await operations.performMutation(token, code)
        try validate(expectedSession: expectedSession, operations: operations)
        try await operations.installSession(sessionID)
    }

    private func validate(
        expectedSession: AuthSessionIdentity,
        operations: SignInChallengeOperations
    ) throws {
        guard expectedSession.permitsChallengeMutation(
            current: operations.currentSession(),
            isAuthenticated: operations.isAuthenticated()
        ) else {
            throw AuthError.sessionChanged
        }
    }
}
