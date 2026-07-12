import Foundation
@testable import HackersPub
import SwiftUI
import Testing

struct BrowserPresentationCoordinatorTests {
    @Test func rapidAndDuplicateRequestsRemainInFIFOOrder() throws {
        var coordinator = BrowserPresentationCoordinator()
        let url = try #require(URL(string: "https://example.com/duplicate"))
        let first = InAppBrowserDestination(url: url)
        let duplicate = InAppBrowserDestination(url: url)
        let third = try InAppBrowserDestination(url: #require(URL(string: "https://example.com/third")))

        coordinator.enqueue(first)
        coordinator.enqueue(duplicate)
        coordinator.enqueue(third)

        #expect(coordinator.destination == first)
        #expect(coordinator.queuedDestinations == [duplicate, third])

        coordinator.dismissed(presentationID: first.id)
        #expect(coordinator.destination == duplicate)

        coordinator.dismissed(presentationID: duplicate.id)
        #expect(coordinator.destination == third)
    }

    @Test func staleDismissalPromotesTheQueueWithoutClearingItsNewOwner() throws {
        var coordinator = BrowserPresentationCoordinator()
        let first = try InAppBrowserDestination(url: #require(URL(string: "https://example.com/first")))
        let second = try InAppBrowserDestination(url: #require(URL(string: "https://example.com/second")))

        coordinator.enqueue(first)
        coordinator.enqueue(second)

        let firstDismissed = coordinator.dismissed(presentationID: first.id)
        #expect(firstDismissed)
        #expect(coordinator.destination == second)

        let staleDismissed = coordinator.dismissed(presentationID: first.id)
        #expect(!staleDismissed)
        #expect(coordinator.destination == second)
    }

    @Test func duplicateCallbacksCannotSkipMultipleQueuedDestinations() throws {
        var coordinator = BrowserPresentationCoordinator()
        let first = try InAppBrowserDestination(url: #require(URL(string: "https://example.com/first")))
        let second = try InAppBrowserDestination(url: #require(URL(string: "https://example.com/second")))
        let third = try InAppBrowserDestination(url: #require(URL(string: "https://example.com/third")))

        coordinator.enqueue(first)
        coordinator.enqueue(second)
        coordinator.enqueue(third)

        let firstDismissed = coordinator.dismissed(presentationID: first.id)
        let firstDuplicate = coordinator.dismissed(presentationID: first.id)
        let secondDuplicate = coordinator.dismissed(presentationID: first.id)
        #expect(firstDismissed)
        #expect(!firstDuplicate)
        #expect(!secondDuplicate)

        #expect(coordinator.destination == second)
        #expect(coordinator.queuedDestinations == [third])
    }

    @Test @MainActor func programmaticCancellationAndDuplicatesPreserveThreeItemFIFO() throws {
        let router = ExternalURLRouter()
        let adapter = BrowserSheetPresentationAdapter(router: router)
        let firstURL = try #require(URL(string: "https://example.com/first"))
        let secondURL = try #require(URL(string: "https://example.com/second"))
        let thirdURL = try #require(URL(string: "https://example.com/third"))

        router.openInApp(firstURL)
        let first = try #require(adapter.presentation)
        router.openInApp(secondURL)
        router.openInApp(thirdURL)

        first.destinationBinding.wrappedValue = nil

        let second = try #require(adapter.presentation)
        #expect(second.destination.url == secondURL)

        first.onDismiss()
        first.onDismiss()
        first.destinationBinding.wrappedValue = nil

        #expect(adapter.presentation?.id == second.id)

        second.destinationBinding.wrappedValue = nil
        second.onDismiss()
        let third = try #require(adapter.presentation)
        #expect(third.destination.url == thirdURL)

        third.destinationBinding.wrappedValue = nil
        third.onDismiss()
        #expect(adapter.presentation?.id == nil)
    }

    @Test @MainActor func requestEnqueuedDuringDismissalSurvivesTheOldOnDismiss() throws {
        let router = ExternalURLRouter()
        let adapter = BrowserSheetPresentationAdapter(router: router)
        let firstURL = try #require(URL(string: "https://example.com/first"))
        let secondURL = try #require(URL(string: "https://example.com/second"))

        router.openInApp(firstURL)
        let first = try #require(adapter.presentation)

        first.destinationBinding.wrappedValue = nil
        router.openInApp(secondURL)
        first.onDismiss()

        #expect(adapter.presentation?.destination.url == secondURL)
    }

    @Test @MainActor func lateBindingCallbackCannotConsumeSuccessorAfterOnDismissPromotesIt() throws {
        let router = ExternalURLRouter()
        let adapter = BrowserSheetPresentationAdapter(router: router)
        let firstURL = try #require(URL(string: "https://example.com/first"))
        let secondURL = try #require(URL(string: "https://example.com/second"))
        let thirdURL = try #require(URL(string: "https://example.com/third"))

        router.openInApp(firstURL)
        let first = try #require(adapter.presentation)
        router.openInApp(secondURL)
        router.openInApp(thirdURL)

        first.onDismiss()
        let second = try #require(adapter.presentation)
        first.destinationBinding.wrappedValue = nil
        first.onDismiss()

        #expect(adapter.presentation?.id == second.id)

        second.onDismiss()
        let third = try #require(adapter.presentation)
        second.destinationBinding.wrappedValue = nil

        #expect(adapter.presentation?.id == third.id)
    }

    @Test @MainActor func slowPresentationIsNotSilentlyExpired() async throws {
        let router = ExternalURLRouter()
        let adapter = BrowserSheetPresentationAdapter(router: router)
        let url = try #require(URL(string: "https://example.com/slow"))

        router.openInApp(url)
        let presentation = try #require(adapter.presentation)

        try await Task.sleep(nanoseconds: 1_100_000_000)

        #expect(adapter.presentation?.id == presentation.id)
    }
}
