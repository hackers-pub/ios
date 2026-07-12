import Foundation
import Observation

@Observable
@MainActor
final class SearchRecentStore {
    static let storageKey = "recentSearches"
    private static let maximumSearches = 10

    private let defaults: UserDefaults
    private let key: String

    private(set) var searches: [String]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        key = Self.storageKey
        #if DEBUG
            if UITestLaunchConfiguration.seedsRecentSearch {
                searches = ["UI test recent search"]
                return
            }
            if UITestLaunchConfiguration.resetsSearchState {
                searches = []
                return
            }
        #endif
        let storedData = defaults.data(forKey: key) ?? Data()
        let storedSearches = (try? JSONDecoder().decode([String].self, from: storedData)) ?? []
        searches = Self.canonicalized(storedSearches)
    }

    func record(_ rawQuery: String) {
        let query = Self.normalized(rawQuery)
        guard !query.isEmpty else { return }

        searches.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
        searches.insert(query, at: 0)
        searches = Array(searches.prefix(Self.maximumSearches))
        persist()
    }

    func delete(_ rawQuery: String) {
        let query = Self.normalized(rawQuery)
        guard !query.isEmpty else { return }

        let updatedSearches = searches.filter { $0.caseInsensitiveCompare(query) != .orderedSame }
        guard updatedSearches.count != searches.count else { return }
        searches = updatedSearches
        persist()
    }

    func clear() {
        guard !searches.isEmpty else { return }
        searches = []
        defaults.removeObject(forKey: key)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(searches) else { return }
        defaults.set(data, forKey: key)
    }

    private static func canonicalized(_ rawSearches: [String]) -> [String] {
        var searches: [String] = []
        for rawQuery in rawSearches {
            let query = normalized(rawQuery)
            guard !query.isEmpty else { continue }
            guard !searches.contains(where: { $0.caseInsensitiveCompare(query) == .orderedSame }) else { continue }
            searches.append(query)
        }
        return Array(searches.prefix(maximumSearches))
    }

    private static func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
