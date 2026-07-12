import Foundation
@testable import HackersPub
import Testing

struct ActorProfileDestinationStateTests {
    @Test func changingTheHandleInvalidatesTheOlderDestinationRequest() {
        var coordinator = ActorProfileDestinationLoadCoordinator()
        let first = coordinator.begin(
            context: ActorProfileDestinationContext(handle: "@first@example.com", accountID: "account-a")
        )
        let second = coordinator.begin(
            context: ActorProfileDestinationContext(handle: "@second@example.com", accountID: "account-a")
        )

        #expect(!coordinator.isCurrent(first))
        #expect(coordinator.isCurrent(second))
        #expect(first.generation < second.generation)
    }

    @Test func retryForTheSameHandleStillRejectsTheOlderCompletion() {
        var coordinator = ActorProfileDestinationLoadCoordinator()
        let context = ActorProfileDestinationContext(handle: "@actor@example.com", accountID: "account-a")
        let first = coordinator.begin(context: context)
        let retry = coordinator.begin(context: context)

        #expect(!coordinator.isCurrent(first))
        #expect(coordinator.isCurrent(retry))
        #expect(retry.generation > first.generation)
    }

    @Test func accountChangesInvalidateResponsesStartedForThePreviousViewer() {
        var coordinator = ActorProfileDestinationLoadCoordinator()
        let oldRequest = coordinator.begin(
            context: ActorProfileDestinationContext(handle: "@actor@example.com", accountID: "account-a")
        )
        let currentRequest = coordinator.begin(
            context: ActorProfileDestinationContext(handle: "@actor@example.com", accountID: "account-b")
        )

        #expect(!coordinator.isCurrent(oldRequest))
        #expect(coordinator.isCurrent(currentRequest))
    }

    @Test func typedFailuresKeepNotFoundSeparateFromTransientFailures() {
        #expect(ActorProfileDestinationFailure.notFound != .graphQL)
        #expect(ActorProfileDestinationFailure.graphQL != .transport)
        #expect(ActorProfileDestinationFailure.notFound.localizationKey == "profile.destination.error.notFound")
        #expect(ActorProfileDestinationFailure.graphQL.localizationKey == "profile.destination.error.unavailable")
        #expect(ActorProfileDestinationFailure.transport.localizationKey == "profile.destination.error.unavailable")
    }

    @Test func destinationContextMatchesCanonicalHandleSpellingsOnly() {
        let context = ActorProfileDestinationContext(handle: " @Alice@Example.COM ", accountID: nil)

        #expect(context.matches(handle: "alice@example.com"))
        #expect(context.matches(handle: "@@ALICE@EXAMPLE.COM"))
        #expect(!context.matches(handle: "bob@example.com"))
    }

    @Test func wrapperUsesLatestContextRetryTypedFailuresAndPreservesLoadedContent() throws {
        let wrapper = try profileSource(named: "ActorProfileViewWrapper.swift")

        #expect(wrapper.contains("authManager.currentAccount?.id"))
        #expect(wrapper.contains(".task(id: destinationContext)"))
        #expect(wrapper.contains("destinationLoadCoordinator.begin"))
        #expect(wrapper.contains("response.errors?.first"))
        #expect(wrapper.contains("LoadFailureView"))
        #expect(wrapper.contains("InlineLoadFailureView"))
        #expect(wrapper.contains("if let actor"))
        #expect(wrapper.contains("destinationContext == context"))
        #expect(!wrapper.contains("Profile not found"))
        #expect(!wrapper.contains("Failed to load profile"))
    }

    @Test func timelineNoLongerOwnsTheProfileDestinationAndEveryNavigationSiteUsesIt() throws {
        let timeline = try repositorySource(at: "HackersPub/Views/TimelineView.swift")
        #expect(!timeline.contains("struct ActorProfileViewWrapper"))

        for sourcePath in [
            "HackersPub/Views/ExploreView.swift",
            "HackersPub/Views/SearchView.swift",
            "HackersPub/Views/NotificationsView.swift",
            "HackersPub/Views/BookmarksView.swift"
        ] {
            let source = try repositorySource(at: sourcePath)
            #expect(source.contains("ActorProfileViewWrapper(handle: handle)"))
        }
    }

    @Test func profileDestinationStringsArePresentInBothSupportedLocales() throws {
        let englishStrings = try repositorySource(at: "HackersPub/en.lproj/Localizable.strings")
        let koreanStrings = try repositorySource(at: "HackersPub/ko.lproj/Localizable.strings")
        let keys = [
            "profile.destination.loading",
            "profile.destination.error.notFound",
            "profile.destination.error.unavailable"
        ]

        for key in keys {
            #expect(englishStrings.contains("\"\(key)\""))
            #expect(koreanStrings.contains("\"\(key)\""))
        }
    }

    private func profileSource(named fileName: String) throws -> String {
        try repositorySource(at: "HackersPub/Views/Profile/\(fileName)")
    }

    private func repositorySource(at relativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
