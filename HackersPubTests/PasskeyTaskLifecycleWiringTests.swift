import Apollo
import ApolloAPI
import Foundation
@testable import HackersPub
import Testing

private actor PasskeyLifecycleCredentialStore: SessionCredentialStore {
    private var values: [String: String]

    init(values: [String: String]) {
        self.values = values
    }

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
}

private actor PasskeyLifecycleInvalidationStore: SessionInvalidationStore {
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

private final class PasskeyLifecycleNetworkTransport: NetworkTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var passkeyRequests = 0
    private var passkeyCursors: [String?] = []

    func send<Query: GraphQLQuery>(
        query: Query,
        fetchBehavior _: FetchBehavior,
        requestConfiguration _: RequestConfiguration
    ) throws -> AsyncThrowingStream<GraphQLResponse<Query>, any Error> {
        if Query.operationName == HackersPub.ViewerQuery.operationName {
            return failingStream(URLError(.notConnectedToInternet))
        }

        if Query.operationName == HackersPub.ViewerPasskeysQuery.operationName {
            let cursor = (query as? HackersPub.ViewerPasskeysQuery)?.after.unwrapped
            lock.lock()
            passkeyRequests += 1
            let requestNumber = passkeyRequests
            passkeyCursors.append(cursor)
            lock.unlock()

            switch requestNumber {
            case 1:
                return responseStream(
                    data: passkeyResponse(
                        id: "passkey-1",
                        hasNextPage: true,
                        endCursor: "page-1"
                    )
                )
            case 2:
                return responseStream(
                    data: passkeyResponse(
                        id: "passkey-2",
                        hasNextPage: false,
                        endCursor: nil
                    )
                )
            default:
                return failingStream(CancellationError())
            }
        }

        return failingStream(URLError(.unsupportedURL))
    }

    func send<Mutation: GraphQLMutation>(
        mutation _: Mutation,
        requestConfiguration _: RequestConfiguration
    ) throws -> AsyncThrowingStream<GraphQLResponse<Mutation>, any Error> {
        failingStream(URLError(.unsupportedURL))
    }

    private func responseStream<Query: GraphQLQuery>(
        data: [String: Any]
    ) -> AsyncThrowingStream<GraphQLResponse<Query>, any Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let responseData = try await Query.Data(data: data)
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

    func requestedPasskeyCursors() -> [String?] {
        lock.lock()
        defer { lock.unlock() }
        return passkeyCursors
    }

    private func passkeyResponse(
        id: String,
        hasNextPage: Bool,
        endCursor: String?
    ) -> [String: Any] {
        let passkey: [String: Any] = [
            "__typename": "Passkey",
            "id": id,
            "name": "MacBook",
            "created": "2026-07-12T00:00:00Z",
            "lastUsed": NSNull()
        ]
        let edge: [String: Any] = [
            "__typename": "AccountPasskeysConnectionEdge",
            "cursor": "edge-\(id)",
            "node": passkey
        ]
        let pageInfo: [String: Any] = [
            "__typename": "PageInfo",
            "hasNextPage": hasNextPage,
            "endCursor": endCursor.map { $0 as Any } ?? NSNull()
        ]
        let passkeys: [String: Any] = [
            "__typename": "AccountPasskeysConnection",
            "edges": [edge],
            "pageInfo": pageInfo
        ]
        let viewer: [String: Any] = [
            "__typename": "Account",
            "id": "account-1",
            "passkeys": passkeys
        ]
        return ["viewer": viewer]
    }
}

struct PasskeyTaskLifecycleWiringTests {
    @Test @MainActor
    func cancelledPasskeyLoadKeepsPreviouslyLoadedItemsAndReturnsToIdle() async {
        let credentials = PasskeyLifecycleCredentialStore(values: ["sessionToken": "session-1"])
        let invalidations = PasskeyLifecycleInvalidationStore()
        let transport = PasskeyLifecycleNetworkTransport()
        let client = ApolloClient(
            networkTransport: transport,
            store: ApolloStore(cache: InMemoryNormalizedCache())
        )
        let manager = AuthManager(
            client: client,
            sessionCredentialStore: credentials,
            sessionInvalidationStore: invalidations
        )

        await manager.loadSession()
        #expect(manager.isAuthenticated)

        await manager.loadPasskeys()
        let loadedPasskeys = manager.passkeys
        #expect(loadedPasskeys.map(\.id) == ["passkey-1", "passkey-2"])
        #expect(transport.requestedPasskeyCursors() == [nil, "page-1"])

        await manager.loadPasskeys()

        #expect(manager.passkeys == loadedPasskeys)
        #expect(manager.passkeyListLoadState == .idle)
        #expect(manager.passkeysLoadError == nil)
        #expect(transport.requestedPasskeyCursors() == [nil, "page-1", nil])
    }

    @Test @MainActor
    func replacingAndCancellingOwnedPasskeyTasksPropagatesCancellation() async {
        let probe = PasskeyTaskCancellationProbe()
        let owner = PasskeyTaskOwner()

        owner.start {
            await probe.run(id: "cancelled-before-start")
        }
        owner.cancel()
        await Task.yield()

        owner.start {
            await probe.run(id: "first")
        }
        await probe.waitUntilStarted(id: "first")

        owner.start {
            await probe.run(id: "replacement")
        }
        await probe.waitUntilCancelled(id: "first")
        await probe.waitUntilStarted(id: "replacement")

        owner.cancel()
        await probe.waitUntilCancelled(id: "replacement")

        let startedIDs = await probe.startedIDs()
        let cancelledIDs = await probe.cancelledIDs()
        #expect(startedIDs == ["first", "replacement"])
        #expect(cancelledIDs == ["first", "replacement"])
    }

    @Test
    func cancelledPasskeyWorkIsSilentThroughTheProductionPresentationPolicy() {
        #expect(!PasskeyAuthorizationErrorPolicy.shouldPresent(CancellationError()))
        #expect(!PasskeyAuthorizationErrorPolicy.shouldPresent(PasskeyServiceError.cancelled))
        #expect(PasskeyAuthorizationErrorPolicy.shouldPresent(PasskeyServiceError.authorizationFailed))
        #expect(PasskeyAuthorizationErrorPolicy.shouldPresent(URLError(.notConnectedToInternet)))
    }
}

private actor PasskeyTaskCancellationProbe {
    private var started: [String] = []
    private var cancelled: [String] = []

    func run(id: String) async {
        started.append(id)
        do {
            try await Task.sleep(nanoseconds: UInt64.max)
        } catch is CancellationError {
            cancelled.append(id)
        } catch {
            Issue.record("Unexpected task-owner probe error: \(error)")
        }
    }

    func waitUntilStarted(id: String) async {
        let deadline = Date().addingTimeInterval(2)
        while !started.contains(id), Date() < deadline {
            await Task.yield()
        }
        if !started.contains(id) {
            Issue.record("Timed out waiting for passkey task \(id) to start")
        }
    }

    func waitUntilCancelled(id: String) async {
        let deadline = Date().addingTimeInterval(2)
        while !cancelled.contains(id), Date() < deadline {
            await Task.yield()
        }
        if !cancelled.contains(id) {
            Issue.record("Timed out waiting for passkey task \(id) to cancel")
        }
    }

    func startedIDs() -> [String] {
        started
    }

    func cancelledIDs() -> [String] {
        cancelled
    }
}
