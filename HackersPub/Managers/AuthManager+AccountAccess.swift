@preconcurrency import Apollo
import Foundation

extension AuthManager {
    func loginByUsername(username: String, verifyUrl: String, locale: String? = nil) async throws -> String {
        let effectiveLocale = AuthLocalePolicy.effectiveLocale(requested: locale)
        let response = try await client.perform(
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
        try await persistAndInstallSession(session.id)
    }

    func signInWithPasskey() async throws {
        let sessionId = UUID().uuidString
        let optionsResponse = try await client.perform(
            mutation: HackersPub.GetPasskeyAuthenticationOptionsMutation(sessionId: sessionId)
        )
        guard let optionsJSON = optionsResponse.data?.getPasskeyAuthenticationOptions else {
            throw AuthError.passkeyFailed
        }

        let options = try PasskeyAuthenticationOptions(json: optionsJSON)
        let authenticationResponse = try await passkeyAuthorizer.authenticate(options: options)
        let loginResponse = try await client.perform(
            mutation: HackersPub.LoginByPasskeyMutation(
                sessionId: sessionId,
                authenticationResponse: authenticationResponse
            )
        )
        guard let session = loginResponse.data?.loginByPasskey else {
            throw AuthError.passkeyFailed
        }
        try await persistAndInstallSession(session.id)
    }

    func registerPasskey(name: String) async throws {
        if currentAccount == nil {
            await fetchViewer()
        }
        guard let accountId = currentAccount?.id else {
            throw AuthError.passkeyFailed
        }

        let optionsResponse = try await client.perform(
            mutation: HackersPub.GetPasskeyRegistrationOptionsMutation(accountId: accountId)
        )
        guard let optionsJSON = optionsResponse.data?.getPasskeyRegistrationOptions else {
            throw AuthError.passkeyFailed
        }

        let options = try PasskeyRegistrationOptions(json: optionsJSON)
        let registrationResponse = try await passkeyAuthorizer.register(options: options)
        let response = try await client.perform(
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
        let response = try await client.perform(
            mutation: HackersPub.RevokePasskeyMutation(passkeyId: id)
        )
        guard response.data?.revokePasskey == id else {
            throw AuthError.passkeyFailed
        }
        removePasskeyFromList(id: id)
    }

    func loadPasskeys() async {
        guard let context = beginPasskeyListRequest() else { return }
        guard let sessionAtLoadStart = context.sessionToken else {
            finishPasskeyListRequest(context: context)
            return
        }

        do {
            let result = try await loadAllPasskeys(
                expectedSessionToken: sessionAtLoadStart,
                currentSessionToken: { self.isAuthenticated ? self.sessionToken : nil },
                fetchPage: { cursor in
                    if let passkeyPageLoader = self.passkeyPageLoader {
                        return try await passkeyPageLoader(cursor)
                    }
                    return try await self.fetchPasskeyPage(after: cursor)
                }
            )
            if case let .loaded(loadedPasskeys) = result {
                completePasskeyListRequest(loadedPasskeys, context: context)
            } else {
                finishPasskeyListRequest(context: context)
            }
        } catch is CancellationError {
            finishPasskeyListRequest(context: context)
        } catch {
            failPasskeyListRequest(error: error, context: context)
        }
    }

    private func fetchPasskeyPage(after cursor: String?) async throws -> PasskeyPage {
        let response = try await client.fetch(
            query: HackersPub.ViewerPasskeysQuery(
                after: cursor.map(GraphQLNullable.some) ?? .none,
                first: Self.passkeyPageSize
            ),
            cachePolicy: .networkOnly
        )
        if let error = response.errors?.first {
            throw PasskeyPaginationError.requestFailed(
                error.message ?? NSLocalizedString("passkey.error.failed", comment: "Passkey operation failed error")
            )
        }
        guard let connection = response.data?.viewer?.passkeys else {
            throw PasskeyPaginationError.missingConnection
        }
        return PasskeyPage(
            passkeys: connection.edges.map {
                PasskeyInfo(id: $0.node.id, name: $0.node.name, created: $0.node.created, lastUsed: $0.node.lastUsed)
            },
            hasNextPage: connection.pageInfo.hasNextPage,
            endCursor: connection.pageInfo.endCursor
        )
    }
}

enum AuthError: LocalizedError {
    case loginFailed
    case accountNotFound
    case verificationFailed
    case passkeyFailed
    case sessionChanged

    var localizationKey: String {
        switch self {
        case .loginFailed:
            "signIn.error.loginFailed"
        case .accountNotFound:
            "signIn.error.accountNotFound"
        case .verificationFailed:
            "signIn.error.verificationFailed"
        case .passkeyFailed:
            "passkey.error.failed"
        case .sessionChanged:
            "signIn.verificationSessionChanged.message"
        }
    }

    var errorDescription: String? {
        NSLocalizedString(localizationKey, comment: "Authentication error")
    }
}
