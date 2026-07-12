import Apollo
import ApolloAPI
import Foundation
@testable import HackersPub
import Testing

struct LegacySessionInvalidationMigrationTests {
    @Test("[AUTH-1] a legacy invalidation marker completes cleanup during session load") @MainActor
    func legacyInvalidationMarkerClearsStoredSessionDuringLoad() async throws {
        let suiteName = "AuthManagerLegacyInvalidationMigrationTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let markerIDKey = "migration.marker.id"
        let markerFingerprintKey = "migration.marker.fingerprint"
        let legacyPendingKey = "migration.legacy.pending"
        defaults.set(true, forKey: legacyPendingKey)

        let credentials = TestSessionCredentialStore(values: ["sessionToken": "legacy-token"])
        await credentials.allowDeletes()
        let invalidations = UserDefaultsSessionInvalidationStore(
            defaults: defaults,
            markerIDKey: markerIDKey,
            markerFingerprintKey: markerFingerprintKey,
            legacyPendingKey: legacyPendingKey
        )
        let manager = AuthManager(
            client: ApolloClient(
                networkTransport: OfflineNetworkTransport(),
                store: ApolloStore(cache: InMemoryNormalizedCache())
            ),
            sessionCredentialStore: credentials,
            sessionInvalidationStore: invalidations
        )

        await manager.loadSession()

        #expect(manager.sessionToken == nil)
        #expect(!manager.isAuthenticated)
        #expect(await credentials.value(for: "sessionToken") == nil)
        #expect(await invalidations.pendingMarker() == nil)
        #expect(defaults.object(forKey: legacyPendingKey) == nil)
        #expect(defaults.object(forKey: markerIDKey) == nil)
        #expect(defaults.object(forKey: markerFingerprintKey) == nil)
    }
}
