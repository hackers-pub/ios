import Foundation
@testable import HackersPub
import Testing

@MainActor
struct SearchRecentStoreTests {
    @Test func recordsNormalizedQueriesWithBoundedCaseInsensitiveDeduplicationAndPersistence() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SearchRecentStore(defaults: defaults)
        for index in 0 ..< 10 {
            store.record("query\(index)")
        }

        store.record("  QUERY3  ")
        store.record("query10")

        #expect(store.searches.count == 10)
        #expect(store.searches.first == "query10")
        #expect(store.searches.dropFirst().first == "QUERY3")
        #expect(!store.searches.contains("query3"))
        #expect(!store.searches.contains("query0"))

        let reloadedStore = SearchRecentStore(defaults: defaults)
        #expect(reloadedStore.searches == store.searches)
    }

    @Test func ignoresEmptySearchesAndPersistsIndividualAndBulkDeletionImmediately() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SearchRecentStore(defaults: defaults)
        store.record("   ")
        store.record("first")
        store.record("second")
        store.delete("FIRST")

        #expect(store.searches == ["second"])
        #expect(SearchRecentStore(defaults: defaults).searches == ["second"])

        store.clear()

        #expect(store.searches.isEmpty)
        #expect(SearchRecentStore(defaults: defaults).searches.isEmpty)
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "SearchRecentStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
