import Apollo
import Foundation
@testable import HackersPub
import Testing

struct TimelineProductionWiringTests {
    @Test func allTimelineQueriesUseTheSharedRefreshCoordinatorAndTypedSources() throws {
        let source = try source(named: "HackersPub/Views/TimelineFeedController.swift")

        #expect(source.occurrenceCount(of: "TimelineRefreshCoordinator(") == 1)
        #expect(source.occurrenceCount(of: "limits: .production") == 1)
        #expect(source.occurrenceCount(of: "fetchRefreshPage: {") == 3)
        #expect(source.contains("TimelineInitialRequestFactory.publicTimeline()"))
        #expect(source.contains("TimelineInitialRequestFactory.personalTimeline()"))
        #expect(source.contains("TimelineInitialRequestFactory.localTimeline()"))
        #expect(source.occurrenceCount(of: "postListItemIdentity(rowID: $0.timelineListID, post: $0.node)") == 3)
        #expect(!source.contains("fetchFreshFirstPage"))
    }

    @Test func typedInitialRequestsUseCacheAndNetworkForAllTimelineQueries() {
        let publicRequest: TimelineInitialRequest<HackersPub.PublicTimelineQuery> =
            TimelineInitialRequestFactory.publicTimeline()
        let personalRequest: TimelineInitialRequest<HackersPub.PersonalTimelineQuery> =
            TimelineInitialRequestFactory.personalTimeline()
        let localRequest: TimelineInitialRequest<HackersPub.LocalTimelineQuery> =
            TimelineInitialRequestFactory.localTimeline()

        #expect(publicRequest.cachePolicy == .cacheAndNetwork)
        #expect(personalRequest.cachePolicy == .cacheAndNetwork)
        #expect(localRequest.cachePolicy == .cacheAndNetwork)

        #expect(publicRequest.query.after == .none)
        #expect(publicRequest.query.before == .none)
        #expect(publicRequest.query.first == .some(20))
        #expect(publicRequest.query.last == .none)

        #expect(personalRequest.query.after == .none)
        #expect(personalRequest.query.before == .none)
        #expect(personalRequest.query.first == .some(20))
        #expect(personalRequest.query.last == .none)

        #expect(localRequest.query.after == .none)
        #expect(localRequest.query.before == .none)
        #expect(localRequest.query.first == .some(20))
        #expect(localRequest.query.last == .none)
    }

    @Test func partialRefreshWarningsAreLocalizedAndRemainRetryableInPrimaryTimelineScopes() throws {
        let timelineSource = try source(named: "HackersPub/Views/TimelineFeedController.swift")
        let loadFailureSource = try source(named: "HackersPub/Views/LoadFailureView.swift")
        let english = try source(named: "HackersPub/en.lproj/Localizable.strings")
        let korean = try source(named: "HackersPub/ko.lproj/Localizable.strings")

        #expect(
            timelineSource.occurrenceCount(
                of: "warning: TimelineRefreshWarning.graphQLPartialResponse(debugMessages: response.errorMessages)"
            ) == 1
        )
        #expect(timelineSource.occurrenceCount(of: "try await timelineRefreshResponse(userMessage:") == 1)
        #expect(!timelineSource.contains("warningMessage: response.errorMessages.first"))
        #expect(!timelineSource.contains("TimelineRefreshError(message: response.errorMessages.first"))
        #expect(!timelineSource.contains("response.errorMessages.first ??"))
        #expect(loadFailureSource.contains("NSLocalizedString(\"common.retry\""))
        #expect(english.contains("\"timeline.refresh.partialWarning\""))
        #expect(english.contains("Some posts could not be refreshed. Retry to load the complete timeline."))
        #expect(korean.contains("\"timeline.refresh.partialWarning\""))
        #expect(korean.contains("일부 게시물을 새로 고치지 못했습니다. 전체 타임라인을 불러오려면 다시 시도해 주세요."))
    }

    private func source(named relativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}

private extension String {
    func occurrenceCount(of needle: String) -> Int {
        components(separatedBy: needle).count - 1
    }
}
