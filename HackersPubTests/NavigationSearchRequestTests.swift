@testable import HackersPub
import Testing

struct NavigationSearchRequestTests {
    @Test @MainActor func contentViewConsumerAppliesAndClearsARequestedSearch() {
        let coordinator = NavigationCoordinator()
        let consumer = ContentViewSearchRequestConsumer(navigationCoordinator: coordinator)
        var appliedQuery: String?

        coordinator.openSearch(query: "swift")
        let request = consumer.consume { appliedQuery = $0 }

        #expect(request?.query == "swift")
        #expect(appliedQuery == "swift")
        #expect(coordinator.requestedSearch == nil)
    }

    @Test @MainActor func contentViewConsumerConsumesRepeatedSameQueryRequests() {
        let coordinator = NavigationCoordinator()
        let consumer = ContentViewSearchRequestConsumer(navigationCoordinator: coordinator)
        var appliedQueries: [String] = []

        coordinator.openSearch(query: "swift")
        let firstRequest = consumer.consume { appliedQueries.append($0) }
        coordinator.openSearch(query: "swift")
        let secondRequest = consumer.consume { appliedQueries.append($0) }

        #expect(firstRequest?.id != secondRequest?.id)
        #expect(appliedQueries == ["swift", "swift"])
        #expect(coordinator.requestedSearch == nil)
    }
}
