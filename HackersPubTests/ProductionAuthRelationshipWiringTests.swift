// swiftlint:disable file_length
import Apollo
import ApolloAPI
import Foundation
@testable import HackersPub
import Testing

private actor ProductionAuthCredentialStore: SessionCredentialStore {
    private var values: [String: String] = [:]

    func save(key: String, value: String) async throws {
        values[key] = value
    }

    func get(key: String) async throws -> String? {
        values[key]
    }

    func delete(key: String) async throws {
        values[key] = nil
    }

    func delete(key: String, matchingValue: String) async throws -> Bool {
        guard values[key] == matchingValue else { return false }
        values[key] = nil
        return true
    }

    func value(for key: String) -> String? {
        values[key]
    }
}

private actor ProductionAuthInvalidationStore: SessionInvalidationStore {
    private var marker: SessionInvalidationMarker?

    func pendingMarker() -> SessionInvalidationMarker? {
        marker
    }

    func markPending(_ marker: SessionInvalidationMarker) {
        self.marker = marker
    }

    func clearPending(_ marker: SessionInvalidationMarker) {
        guard self.marker == marker else { return }
        self.marker = nil
    }

    func clearPending() {
        marker = nil
    }
}

@MainActor
private final class ProductionPasskeyAuthorizerSpy: PasskeyAuthorizing {
    let authenticationResponse = HackersPub.JSON(
        encodableDictionary: ["kind": "authentication"]
    )
    let registrationResponse = HackersPub.JSON(
        encodableDictionary: ["kind": "registration"]
    )
    private(set) var authenticationRelyingPartyIDs: [String] = []
    private(set) var registrationNames: [String] = []

    func authenticate(options: PasskeyAuthenticationOptions) async throws -> HackersPub.JSON {
        authenticationRelyingPartyIDs.append(options.relyingPartyID)
        return authenticationResponse
    }

    func register(options: PasskeyRegistrationOptions) async throws -> HackersPub.JSON {
        registrationNames.append(options.name)
        return registrationResponse
    }
}

private final class ProductionAuthNetworkTransport: NetworkTransport, @unchecked Sendable {
    struct Snapshot: Equatable {
        let operationNames: [String]
        let authenticationOptionsSessionID: String?
        let loginSessionID: String?
        let loginAuthenticationResponse: HackersPub.JSON?
        let registrationName: String?
        let registrationResponse: HackersPub.JSON?
    }

    private let lock = NSLock()
    private var operationNames: [String] = []
    private var authenticationOptionsSessionID: String?
    private var loginSessionID: String?
    private var loginAuthenticationResponse: HackersPub.JSON?
    private var registrationName: String?
    private var registrationResponse: HackersPub.JSON?

    func send<Query: GraphQLQuery>(
        query _: Query,
        fetchBehavior _: FetchBehavior,
        requestConfiguration _: RequestConfiguration
    ) throws -> AsyncThrowingStream<GraphQLResponse<Query>, any Error> {
        record(operationName: Query.operationName)
        switch Query.operationName {
        case HackersPub.ViewerQuery.operationName:
            return responseStream(data: viewerResponse())
        case HackersPub.ViewerPasskeysQuery.operationName:
            return responseStream(data: viewerPasskeysResponse())
        default:
            return failingStream(URLError(.unsupportedURL))
        }
    }

    func send<Mutation: GraphQLMutation>(
        mutation: Mutation,
        requestConfiguration _: RequestConfiguration
    ) throws -> AsyncThrowingStream<GraphQLResponse<Mutation>, any Error> {
        record(operationName: Mutation.operationName)

        if let mutation = mutation as? HackersPub.GetPasskeyAuthenticationOptionsMutation {
            lock.lock()
            authenticationOptionsSessionID = mutation.sessionId
            lock.unlock()
            return responseStream(data: authenticationOptionsResponse())
        }
        if let mutation = mutation as? HackersPub.LoginByPasskeyMutation {
            lock.lock()
            loginSessionID = mutation.sessionId
            loginAuthenticationResponse = mutation.authenticationResponse
            lock.unlock()
            return responseStream(data: loginResponse())
        }
        if mutation is HackersPub.GetPasskeyRegistrationOptionsMutation {
            return responseStream(data: registrationOptionsResponse())
        }
        if let mutation = mutation as? HackersPub.VerifyPasskeyRegistrationMutation {
            lock.lock()
            registrationName = mutation.name
            registrationResponse = mutation.registrationResponse
            lock.unlock()
            return responseStream(data: registrationVerificationResponse())
        }
        return failingStream(URLError(.unsupportedURL))
    }

    func snapshot() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return Snapshot(
            operationNames: operationNames,
            authenticationOptionsSessionID: authenticationOptionsSessionID,
            loginSessionID: loginSessionID,
            loginAuthenticationResponse: loginAuthenticationResponse,
            registrationName: registrationName,
            registrationResponse: registrationResponse
        )
    }

    private func record(operationName: String) {
        lock.lock()
        operationNames.append(operationName)
        lock.unlock()
    }

    private func responseStream<Operation: GraphQLOperation>(
        data: [String: Any]
    ) -> AsyncThrowingStream<GraphQLResponse<Operation>, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let responseData = try await Operation.Data(data: data)
                    continuation.yield(
                        GraphQLResponse(
                            data: responseData,
                            extensions: nil,
                            errors: nil,
                            source: .server,
                            dependentKeys: nil
                        )
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func failingStream<Operation: GraphQLOperation>(
        _ error: any Error
    ) -> AsyncThrowingStream<GraphQLResponse<Operation>, any Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: error)
        }
    }

    private func authenticationOptionsResponse() -> [String: Any] {
        [
            "getPasskeyAuthenticationOptions": [
                "challenge": "Y2hhbGxlbmdl",
                "rpId": "hackers.pub"
            ]
        ]
    }

    private func loginResponse() -> [String: Any] {
        [
            "loginByPasskey": [
                "__typename": "Session",
                "id": "session-new",
                "account": [
                    "__typename": "Account",
                    "id": "account-1",
                    "username": "alice",
                    "name": "Alice",
                    "avatarUrl": "https://hackers.pub/avatar.png",
                    "handle": "@alice@hackers.pub"
                ]
            ]
        ]
    }

    private func viewerResponse() -> [String: Any] {
        [
            "viewer": [
                "__typename": "Account",
                "id": "account-1",
                "username": "alice",
                "name": "Alice",
                "bio": "",
                "avatarMediumId": NSNull(),
                "avatarUrl": "https://hackers.pub/avatar.png",
                "handle": "@alice@hackers.pub",
                "links": []
            ]
        ]
    }

    private func registrationOptionsResponse() -> [String: Any] {
        [
            "getPasskeyRegistrationOptions": [
                "challenge": "Y2hhbGxlbmdl",
                "rp": ["id": "hackers.pub"],
                "user": [
                    "id": "dXNlci1pZA",
                    "name": "alice"
                ]
            ]
        ]
    }

    private func registrationVerificationResponse() -> [String: Any] {
        [
            "verifyPasskeyRegistration": [
                "__typename": "PasskeyRegistrationResult",
                "verified": true,
                "passkey": [
                    "__typename": "Passkey",
                    "id": "registered-passkey",
                    "name": "MacBook",
                    "created": "2026-07-12T00:00:00Z",
                    "lastUsed": NSNull()
                ]
            ]
        ]
    }

    private func viewerPasskeysResponse() -> [String: Any] {
        [
            "viewer": [
                "__typename": "Account",
                "id": "account-1",
                "passkeys": [
                    "__typename": "AccountPasskeysConnection",
                    "edges": [[
                        "__typename": "AccountPasskeysConnectionEdge",
                        "cursor": "registered-cursor",
                        "node": [
                            "__typename": "Passkey",
                            "id": "registered-passkey",
                            "name": "MacBook",
                            "created": "2026-07-12T00:00:00Z",
                            "lastUsed": NSNull()
                        ]
                    ]],
                    "pageInfo": [
                        "__typename": "PageInfo",
                        "hasNextPage": false,
                        "endCursor": NSNull()
                    ]
                ]
            ]
        ]
    }
}

@MainActor
struct ProductionAuthRelationshipWiringTests {
    @Test
    func passkeyAndRelationshipAPIsKeepTypedProductionSeams() {
        let authorizer: any PasskeyAuthorizing = PasskeyService.shared
        let fetch: (String, CachePolicy.Query.SingleResponse) async throws -> ActorRelationshipState? =
            ActorRelationshipService.fetch(handle:cachePolicy:)
        let perform: (ActorRelationshipAction, String) async throws -> Void = { action, actorID in
            _ = try await ActorRelationshipService.perform(action: action, actorId: actorID)
        }
        let gate = ActorRelationshipStateUpdateGate()
        let begin: (String) -> ActorRelationshipRequestToken = gate.begin(handle:)
        let invalidate: () -> Void = gate.invalidate
        let allows: (ActorRelationshipRequestToken, String?) -> Bool =
            gate.allows(_:currentHandle:)
        let request = begin("@alice")

        #expect(allows(request, "@alice"))
        invalidate()
        #expect(!allows(request, "@alice"))
        _ = authorizer
        _ = fetch
        _ = perform
    }

    @Test
    func authManagerExecutesTypedPasskeySignInAndRegistrationFlows() async throws {
        let credentials = ProductionAuthCredentialStore()
        let invalidations = ProductionAuthInvalidationStore()
        let transport = ProductionAuthNetworkTransport()
        let authorizer = ProductionPasskeyAuthorizerSpy()
        let manager = AuthManager(
            client: ApolloClient(
                networkTransport: transport,
                store: ApolloStore(cache: InMemoryNormalizedCache())
            ),
            sessionCredentialStore: credentials,
            sessionInvalidationStore: invalidations,
            passkeyAuthorizer: authorizer
        )

        try await manager.signInWithPasskey()
        try await manager.registerPasskey(name: "MacBook")

        let snapshot = transport.snapshot()
        let persistedSessionToken = await credentials.value(for: "sessionToken")
        #expect(authorizer.authenticationRelyingPartyIDs == ["hackers.pub"])
        #expect(authorizer.registrationNames == ["alice"])
        #expect(snapshot.authenticationOptionsSessionID == snapshot.loginSessionID)
        #expect(snapshot.loginAuthenticationResponse == authorizer.authenticationResponse)
        #expect(snapshot.registrationName == "MacBook")
        #expect(snapshot.registrationResponse == authorizer.registrationResponse)
        #expect(persistedSessionToken == "session-new")
        #expect(manager.currentAccount?.id == "account-1")
        #expect(manager.passkeys.map(\.id) == ["registered-passkey"])
        #expect(
            snapshot.operationNames == [
                HackersPub.GetPasskeyAuthenticationOptionsMutation.operationName,
                HackersPub.LoginByPasskeyMutation.operationName,
                HackersPub.ViewerQuery.operationName,
                HackersPub.GetPasskeyRegistrationOptionsMutation.operationName,
                HackersPub.VerifyPasskeyRegistrationMutation.operationName,
                HackersPub.ViewerPasskeysQuery.operationName
            ]
        )
    }

    @Test
    func partialRelationshipDataAndLatestGenerationAreBehaviorallyEnforced() throws {
        let relationship = ActorRelationshipState(
            actorId: "actor-1",
            handle: "@alice",
            isViewer: false,
            viewerFollows: true,
            followsViewer: false,
            viewerBlocks: false
        )

        #expect(
            try ActorRelationshipService.resolveFetchResult(
                graphQLErrorsPresent: true,
                relationship: relationship
            ) == relationship
        )
        do {
            _ = try ActorRelationshipService.resolveFetchResult(
                graphQLErrorsPresent: true,
                relationship: nil
            )
            Issue.record("Expected queryFailed relationship response")
        } catch let error as ActorRelationshipServiceError {
            guard case .queryFailed = error else {
                Issue.record("Expected queryFailed relationship response, received \(error)")
                return
            }
        } catch {
            Issue.record("Expected ActorRelationshipServiceError, received \(error)")
        }

        let gate = ActorRelationshipStateUpdateGate()
        let staleRequest = gate.begin(handle: "@alice")
        let latestRequest = gate.begin(handle: "@bob")
        #expect(!gate.allows(staleRequest, currentHandle: "@alice"))
        #expect(gate.allows(latestRequest, currentHandle: "@bob"))

        gate.invalidate()
        #expect(!gate.allows(latestRequest, currentHandle: "@bob"))
    }
}
