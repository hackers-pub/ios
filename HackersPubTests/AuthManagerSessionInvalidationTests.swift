// swiftlint:disable file_length
import Apollo
import ApolloAPI
import Foundation
@testable import HackersPub
import Security
import Testing

actor TestSessionCredentialStore: SessionCredentialStore {
    private var values: [String: String]
    private var deleteShouldFail = true
    private var suspendNextGet: Bool
    private var protectedReadFailures: Int
    private var getDidSuspend = false
    private var suspendedGetWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseGetContinuations: [CheckedContinuation<Void, Never>] = []
    private var suspendNextSave = false
    private var saveDidSuspend = false
    private var saveWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseSaveContinuations: [CheckedContinuation<Void, Never>] = []

    init(
        values: [String: String],
        suspendNextGet: Bool = false,
        protectedReadFailures: Int = 0
    ) {
        self.values = values
        self.suspendNextGet = suspendNextGet
        self.protectedReadFailures = protectedReadFailures
    }

    func save(key: String, value: String) async throws {
        if suspendNextSave {
            suspendNextSave = false
            saveDidSuspend = true
            let waiters = saveWaiters
            saveWaiters.removeAll()
            waiters.forEach { $0.resume() }
            await withCheckedContinuation { continuation in
                releaseSaveContinuations.append(continuation)
            }
        }
        values[key] = value
    }

    func get(key: String) async throws -> String? {
        if protectedReadFailures > 0 {
            protectedReadFailures -= 1
            throw KeychainError.unexpectedStatus(errSecInteractionNotAllowed)
        }

        let capturedValue = values[key]
        if suspendNextGet {
            suspendNextGet = false
            getDidSuspend = true
            let waiters = suspendedGetWaiters
            suspendedGetWaiters.removeAll()
            waiters.forEach { $0.resume() }
            await withCheckedContinuation { continuation in
                releaseGetContinuations.append(continuation)
            }
        }
        return capturedValue
    }

    func delete(key: String) async throws {
        guard !deleteShouldFail else {
            throw KeychainError.unexpectedStatus(errSecNotAvailable)
        }
        values[key] = nil
    }

    func delete(key: String, matchingValue: String) async throws -> Bool {
        guard values[key] == matchingValue else { return false }
        try await delete(key: key)
        return true
    }

    func allowDeletes() {
        deleteShouldFail = false
    }

    func value(for key: String) -> String? {
        values[key]
    }

    func waitForSuspendedGet() async {
        guard !getDidSuspend else { return }
        await withCheckedContinuation { continuation in
            suspendedGetWaiters.append(continuation)
        }
    }

    func releaseSuspendedGet() {
        let continuations = releaseGetContinuations
        releaseGetContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }

    func suspendFollowingSave() {
        suspendNextSave = true
    }

    func waitForSuspendedSave() async {
        guard !saveDidSuspend else { return }
        await withCheckedContinuation { continuation in
            saveWaiters.append(continuation)
        }
    }

    func releaseSuspendedSave() {
        let continuations = releaseSaveContinuations
        releaseSaveContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }
}

private actor TestSessionInvalidationStore: SessionInvalidationStore {
    private var marker: SessionInvalidationMarker?
    private var suspendNextMark = false
    private var markDidSuspend = false
    private var markSuspensionCount = 0
    private var markWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseMarkContinuations: [CheckedContinuation<Void, Never>] = []
    private var suspendNextClear = false
    private var clearDidSuspend = false
    private var clearWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseClearContinuations: [CheckedContinuation<Void, Never>] = []

    func pendingMarker() -> SessionInvalidationMarker? {
        marker
    }

    func markPending(_ marker: SessionInvalidationMarker) async {
        self.marker = marker
        guard suspendNextMark else { return }
        suspendNextMark = false
        markDidSuspend = true
        markSuspensionCount += 1
        let waiters = markWaiters
        markWaiters.removeAll()
        waiters.forEach { $0.resume() }
        await withCheckedContinuation { continuation in
            releaseMarkContinuations.append(continuation)
        }
    }

    func clearPending(_ marker: SessionInvalidationMarker) async {
        guard self.marker == marker else { return }
        guard suspendNextClear else {
            self.marker = nil
            return
        }
        suspendNextClear = false
        clearDidSuspend = true
        let waiters = clearWaiters
        clearWaiters.removeAll()
        waiters.forEach { $0.resume() }
        await withCheckedContinuation { continuation in
            releaseClearContinuations.append(continuation)
        }
        guard self.marker == marker else { return }
        self.marker = nil
    }

    func clearPending() async {
        guard suspendNextClear else {
            marker = nil
            return
        }
        suspendNextClear = false
        clearDidSuspend = true
        let waiters = clearWaiters
        clearWaiters.removeAll()
        waiters.forEach { $0.resume() }
        await withCheckedContinuation { continuation in
            releaseClearContinuations.append(continuation)
        }
        marker = nil
    }

    func suspendFollowingMark() {
        suspendNextMark = true
    }

    func waitForSuspendedMark() async {
        guard !markDidSuspend else { return }
        await withCheckedContinuation { continuation in
            markWaiters.append(continuation)
        }
    }

    func suspendedMarkCount() -> Int {
        markSuspensionCount
    }

    func waitForSuspendedMark(after count: Int) async {
        guard markSuspensionCount <= count else { return }
        await withCheckedContinuation { continuation in
            markWaiters.append(continuation)
        }
    }

    func releaseSuspendedMark() {
        let continuations = releaseMarkContinuations
        releaseMarkContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }

    func suspendFollowingClear() {
        suspendNextClear = true
    }

    func waitForSuspendedClear() async {
        guard !clearDidSuspend else { return }
        await withCheckedContinuation { continuation in
            clearWaiters.append(continuation)
        }
    }

    func releaseSuspendedClear() {
        let continuations = releaseClearContinuations
        releaseClearContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }
}

private actor RevokeSuspensionRecorder {
    private var revokeDidStart = false
    private var revokeWaiters: [CheckedContinuation<Void, Never>] = []
    private var isRevokeReleaseRequested = false
    private var revokeReleaseContinuations: [CheckedContinuation<Void, Never>] = []

    func markRevokeStarted() {
        revokeDidStart = true
        let waiters = revokeWaiters
        revokeWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func waitForRevoke() async {
        guard !revokeDidStart else { return }
        await withCheckedContinuation { continuation in
            revokeWaiters.append(continuation)
        }
    }

    func waitForRelease() async {
        guard !isRevokeReleaseRequested else { return }
        await withCheckedContinuation { continuation in
            revokeReleaseContinuations.append(continuation)
        }
    }

    func releaseRevoke() {
        isRevokeReleaseRequested = true
        let continuations = revokeReleaseContinuations
        revokeReleaseContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }
}

private final class SuspendedRevokeNetworkTransport: NetworkTransport, @unchecked Sendable {
    private let recorder = RevokeSuspensionRecorder()

    func send<Query: GraphQLQuery>(
        query _: Query,
        fetchBehavior _: FetchBehavior,
        requestConfiguration _: RequestConfiguration
    ) throws -> AsyncThrowingStream<GraphQLResponse<Query>, any Error> {
        failingStream()
    }

    func send<Mutation: GraphQLMutation>(
        mutation: Mutation,
        requestConfiguration _: RequestConfiguration
    ) throws -> AsyncThrowingStream<GraphQLResponse<Mutation>, any Error> {
        guard mutation is HackersPub.RevokeSessionMutation else {
            return failingStream()
        }
        return AsyncThrowingStream { continuation in
            Task {
                await recorder.markRevokeStarted()
                await recorder.waitForRelease()
                continuation.finish(throwing: URLError(.notConnectedToInternet))
            }
        }
    }

    func waitForRevoke() async {
        await recorder.waitForRevoke()
    }

    func releaseRevoke() async {
        await recorder.releaseRevoke()
    }

    private func failingStream<Operation: GraphQLOperation>() -> AsyncThrowingStream<
        GraphQLResponse<Operation>,
        any Error
    > {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: URLError(.notConnectedToInternet))
        }
    }
}

final class OfflineNetworkTransport: NetworkTransport, @unchecked Sendable {
    func send<Query: GraphQLQuery>(
        query _: Query,
        fetchBehavior _: FetchBehavior,
        requestConfiguration _: RequestConfiguration
    ) throws -> AsyncThrowingStream<GraphQLResponse<Query>, any Error> {
        failingStream()
    }

    func send<Mutation: GraphQLMutation>(
        mutation _: Mutation,
        requestConfiguration _: RequestConfiguration
    ) throws -> AsyncThrowingStream<GraphQLResponse<Mutation>, any Error> {
        failingStream()
    }

    private func failingStream<Operation: GraphQLOperation>() -> AsyncThrowingStream<
        GraphQLResponse<Operation>,
        any Error
    > {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: URLError(.notConnectedToInternet))
        }
    }
}

// swiftlint:disable:next type_body_length
struct AuthManagerSessionInvalidationTests {
    @Test @MainActor
    func failedDeleteBlocksStaleCredentialAcrossRelaunchUntilCleanupSucceeds() async {
        let credentials = TestSessionCredentialStore(values: ["sessionToken": "stale-token"])
        let invalidations = TestSessionInvalidationStore()
        let client = ApolloClient(
            networkTransport: OfflineNetworkTransport(),
            store: ApolloStore(cache: InMemoryNormalizedCache())
        )
        let manager = AuthManager(
            client: client,
            sessionCredentialStore: credentials,
            sessionInvalidationStore: invalidations
        )

        await manager.loadSession()
        #expect(manager.isAuthenticated)
        #expect(manager.sessionToken == "stale-token")

        await manager.invalidateLocalSession()
        #expect(!manager.isAuthenticated)
        #expect(manager.sessionToken == nil)
        let pendingAfterFailure = await invalidations.pendingMarker()
        let staleCredential = await credentials.value(for: "sessionToken")
        #expect(pendingAfterFailure != nil)
        #expect(staleCredential == "stale-token")

        let relaunchedManager = AuthManager(
            client: client,
            sessionCredentialStore: credentials,
            sessionInvalidationStore: invalidations
        )
        await relaunchedManager.loadSession()
        #expect(!relaunchedManager.isAuthenticated)
        #expect(relaunchedManager.sessionToken == nil)
        #expect(await invalidations.pendingMarker() == pendingAfterFailure)
        #expect(await credentials.value(for: "sessionToken") == "stale-token")

        await credentials.allowDeletes()
        await relaunchedManager.loadSession()
        let pendingAfterCleanup = await invalidations.pendingMarker()
        let credentialAfterCleanup = await credentials.value(for: "sessionToken")
        #expect(pendingAfterCleanup == nil)
        #expect(credentialAfterCleanup == nil)

        let cleanRelaunch = AuthManager(
            client: client,
            sessionCredentialStore: credentials,
            sessionInvalidationStore: invalidations
        )
        await cleanRelaunch.loadSession()
        #expect(!cleanRelaunch.isAuthenticated)
        #expect(cleanRelaunch.sessionToken == nil)
    }

    @Test @MainActor
    func relaunchKeepsANewerCredentialThatDoesNotMatchThePendingMarker() async throws {
        let credentials = TestSessionCredentialStore(values: ["sessionToken": "stale-token"])
        let invalidations = TestSessionInvalidationStore()
        let manager = makeManager(credentials: credentials, invalidations: invalidations)
        await manager.loadSession()
        await manager.invalidateLocalSession()
        #expect(await invalidations.pendingMarker() != nil)

        try await credentials.save(key: "sessionToken", value: "new-token")
        let relaunchedManager = makeManager(credentials: credentials, invalidations: invalidations)
        await relaunchedManager.loadSession()

        #expect(relaunchedManager.isAuthenticated)
        #expect(relaunchedManager.sessionToken == "new-token")
        #expect(await credentials.value(for: "sessionToken") == "new-token")
        #expect(await invalidations.pendingMarker() == nil)
    }

    @Test @MainActor
    func delayedBootLoadCannotOverwriteANewerInstalledSession() async throws {
        let credentials = TestSessionCredentialStore(
            values: ["sessionToken": "old-token"],
            suspendNextGet: true
        )
        let manager = makeManager(credentials: credentials)
        let bootLoad = Task { @MainActor in
            await manager.loadSession()
        }

        await credentials.waitForSuspendedGet()
        try await manager.persistAndInstallSession("new-token")
        let installedGeneration = manager.sessionGeneration

        await credentials.releaseSuspendedGet()
        await bootLoad.value

        #expect(manager.sessionToken == "new-token")
        #expect(manager.sessionGeneration == installedGeneration)
        #expect(manager.isAuthenticated)
        #expect(await credentials.value(for: "sessionToken") == "new-token")
    }

    @Test @MainActor
    func delayedProtectedDataRetryCannotOverwriteANewerInstalledSession() async throws {
        let credentials = TestSessionCredentialStore(
            values: ["sessionToken": "old-token"],
            suspendNextGet: true,
            protectedReadFailures: 1
        )
        let manager = makeManager(credentials: credentials)
        await manager.loadSession()

        let retryLoad = Task { @MainActor in
            await manager.loadSession()
        }
        await credentials.waitForSuspendedGet()
        try await manager.persistAndInstallSession("new-token")
        let installedGeneration = manager.sessionGeneration

        await credentials.releaseSuspendedGet()
        await retryLoad.value

        #expect(manager.sessionToken == "new-token")
        #expect(manager.sessionGeneration == installedGeneration)
        #expect(manager.isAuthenticated)
        #expect(await credentials.value(for: "sessionToken") == "new-token")
    }

    @Test @MainActor
    func delayedViewerInvalidationCannotRemoveANewerSessionOrLeaveItsMarker() async throws {
        let credentials = TestSessionCredentialStore(values: ["sessionToken": "old-token"])
        let invalidations = TestSessionInvalidationStore()
        let manager = makeManager(credentials: credentials, invalidations: invalidations)
        await manager.loadSession()
        let staleIdentity = AuthSessionIdentity(
            token: manager.sessionToken,
            generation: manager.sessionGeneration
        )

        let markSuspensionCount = await invalidations.suspendedMarkCount()
        await invalidations.suspendFollowingMark()
        let staleInvalidation = Task { @MainActor in
            await manager.invalidateLocalSession(expectedIdentity: staleIdentity)
        }
        await invalidations.waitForSuspendedMark(after: markSuspensionCount)

        try await manager.persistAndInstallSession("new-token")
        await invalidations.releaseSuspendedMark()
        await staleInvalidation.value

        #expect(manager.sessionToken == "new-token")
        #expect(manager.isAuthenticated)
        #expect(await credentials.value(for: "sessionToken") == "new-token")
        #expect(await invalidations.pendingMarker() == nil)
    }

    @Test @MainActor
    func invalidationCannotDeleteCredentialSavedBeforeReplacementMarkerClear() async throws {
        let credentials = TestSessionCredentialStore(values: ["sessionToken": "old-token"])
        await credentials.allowDeletes()
        let invalidations = TestSessionInvalidationStore()
        let manager = makeManager(credentials: credentials, invalidations: invalidations)
        await manager.loadSession()
        let staleIdentity = AuthSessionIdentity(
            token: manager.sessionToken,
            generation: manager.sessionGeneration
        )

        await invalidations.suspendFollowingMark()
        let staleInvalidation = Task { @MainActor in
            await manager.invalidateLocalSession(expectedIdentity: staleIdentity)
        }
        await invalidations.waitForSuspendedMark()

        await invalidations.suspendFollowingClear()
        let replacement = Task { @MainActor in
            try await manager.persistAndInstallSession("new-token")
        }
        await invalidations.waitForSuspendedClear()

        await invalidations.releaseSuspendedMark()
        await staleInvalidation.value
        await invalidations.releaseSuspendedClear()
        try await replacement.value

        #expect(manager.sessionToken == "new-token")
        #expect(manager.isAuthenticated)
        #expect(await credentials.value(for: "sessionToken") == "new-token")
        #expect(await invalidations.pendingMarker() == nil)
    }

    @Test @MainActor
    func staleReplacementCannotClearANewerInvalidationMarker() async throws {
        let credentials = TestSessionCredentialStore(values: ["sessionToken": "old-token"])
        await credentials.allowDeletes()
        let invalidations = TestSessionInvalidationStore()
        let transport = SuspendedRevokeNetworkTransport()
        let manager = AuthManager(
            client: ApolloClient(
                networkTransport: transport,
                store: ApolloStore(cache: InMemoryNormalizedCache())
            ),
            sessionCredentialStore: credentials,
            sessionInvalidationStore: invalidations
        )
        await manager.loadSession()
        let staleIdentity = AuthSessionIdentity(
            token: manager.sessionToken,
            generation: manager.sessionGeneration
        )

        await invalidations.suspendFollowingMark()
        let staleInvalidation = Task { @MainActor in
            await manager.invalidateLocalSession(expectedIdentity: staleIdentity)
        }
        await invalidations.waitForSuspendedMark()
        let staleMarker = await invalidations.pendingMarker()

        await invalidations.suspendFollowingClear()
        let replacement = Task { @MainActor in
            try await manager.persistAndInstallSession("new-token")
        }
        await invalidations.waitForSuspendedClear()

        let signOutMarkSuspensionCount = await invalidations.suspendedMarkCount()
        await invalidations.suspendFollowingMark()
        let signOut = Task { @MainActor in
            await manager.signOut()
        }
        await transport.waitForRevoke()
        await transport.releaseRevoke()
        await invalidations.waitForSuspendedMark(after: signOutMarkSuspensionCount)
        let signOutMarker = await invalidations.pendingMarker()
        #expect(signOutMarker != staleMarker)

        await invalidations.releaseSuspendedClear()
        try await replacement.value
        #expect(await invalidations.pendingMarker() == signOutMarker)

        await invalidations.releaseSuspendedMark()
        await staleInvalidation.value
        await signOut.value

        #expect(manager.sessionToken == nil)
        #expect(!manager.isAuthenticated)
        #expect(await credentials.value(for: "sessionToken") == nil)
        #expect(await invalidations.pendingMarker() == nil)
    }

    @Test @MainActor
    func signOutWinsDurablyOverASuspendedReplacementSave() async throws {
        let credentials = TestSessionCredentialStore(values: ["sessionToken": "old-token"])
        await credentials.allowDeletes()
        let invalidations = TestSessionInvalidationStore()
        let transport = SuspendedRevokeNetworkTransport()
        let manager = AuthManager(
            client: ApolloClient(
                networkTransport: transport,
                store: ApolloStore(cache: InMemoryNormalizedCache())
            ),
            sessionCredentialStore: credentials,
            sessionInvalidationStore: invalidations
        )
        await manager.loadSession()

        await credentials.suspendFollowingSave()
        let replacement = Task { @MainActor in
            try await manager.persistAndInstallSession("new-token")
        }
        await credentials.waitForSuspendedSave()

        let signOut = Task { @MainActor in
            await manager.signOut()
        }
        await transport.waitForRevoke()
        await credentials.releaseSuspendedSave()
        try await replacement.value
        await transport.releaseRevoke()
        await signOut.value

        #expect(manager.sessionToken == nil)
        #expect(!manager.isAuthenticated)
        #expect(await credentials.value(for: "sessionToken") == nil)
        #expect(await invalidations.pendingMarker() == nil)
    }

    @Test @MainActor
    func newerReplacementWinsAfterSuspendedSaveThenSignOut() async throws {
        let credentials = TestSessionCredentialStore(values: ["sessionToken": "old-token"])
        await credentials.allowDeletes()
        let invalidations = TestSessionInvalidationStore()
        let transport = SuspendedRevokeNetworkTransport()
        let manager = AuthManager(
            client: ApolloClient(
                networkTransport: transport,
                store: ApolloStore(cache: InMemoryNormalizedCache())
            ),
            sessionCredentialStore: credentials,
            sessionInvalidationStore: invalidations
        )
        await manager.loadSession()

        await credentials.suspendFollowingSave()
        let replacementB = Task { @MainActor in
            try await manager.persistAndInstallSession("token-b")
        }
        await credentials.waitForSuspendedSave()

        let signOut = Task { @MainActor in
            await manager.signOut()
        }
        await transport.waitForRevoke()
        let replacementC = Task { @MainActor in
            try await manager.persistAndInstallSession("token-c")
        }
        await credentials.releaseSuspendedSave()
        try await replacementB.value
        try await replacementC.value
        await transport.releaseRevoke()
        await signOut.value

        #expect(manager.sessionToken == "token-c")
        #expect(manager.isAuthenticated)
        #expect(await credentials.value(for: "sessionToken") == "token-c")
        #expect(await invalidations.pendingMarker() == nil)
    }

    @Test @MainActor
    func delayedManualSignOutCannotRemoveANewerSessionOrLeaveItsMarker() async throws {
        let credentials = TestSessionCredentialStore(values: ["sessionToken": "old-token"])
        let invalidations = TestSessionInvalidationStore()
        let transport = SuspendedRevokeNetworkTransport()
        let manager = AuthManager(
            client: ApolloClient(
                networkTransport: transport,
                store: ApolloStore(cache: InMemoryNormalizedCache())
            ),
            sessionCredentialStore: credentials,
            sessionInvalidationStore: invalidations
        )
        await manager.loadSession()

        let signOut = Task { @MainActor in
            await manager.signOut()
        }
        await transport.waitForRevoke()

        try await manager.persistAndInstallSession("new-token")
        await transport.releaseRevoke()
        await signOut.value

        #expect(manager.sessionToken == "new-token")
        #expect(manager.isAuthenticated)
        #expect(await credentials.value(for: "sessionToken") == "new-token")
        #expect(await invalidations.pendingMarker() == nil)
    }

    @MainActor
    private func makeManager(
        credentials: TestSessionCredentialStore,
        invalidations: TestSessionInvalidationStore = TestSessionInvalidationStore()
    ) -> AuthManager {
        AuthManager(
            client: ApolloClient(
                networkTransport: OfflineNetworkTransport(),
                store: ApolloStore(cache: InMemoryNormalizedCache())
            ),
            sessionCredentialStore: credentials,
            sessionInvalidationStore: invalidations
        )
    }
}
