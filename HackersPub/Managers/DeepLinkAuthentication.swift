struct AuthSessionIdentity: Equatable, Sendable {
    let token: String?
    let generation: UInt64

    func permitsChallengeMutation(
        current: AuthSessionIdentity,
        isAuthenticated: Bool
    ) -> Bool {
        token == nil && !isAuthenticated && self == current
    }
}

@MainActor
protocol DeepLinkAuthenticating: AnyObject {
    var isAuthenticated: Bool { get }
    var sessionIdentity: AuthSessionIdentity { get }

    func completeLoginChallenge(
        token: String,
        code: String,
        expectedSession: AuthSessionIdentity
    ) async throws
}
