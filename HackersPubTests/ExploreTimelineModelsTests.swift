import Apollo
import Foundation
@testable import HackersPub
import Testing

struct ExploreTimelineModelsTests {
    @Test("SOC-14: a cached Explore page survives a terminal network failure")
    @MainActor
    func cachedPageSurvivesTerminalNetworkFailure() async throws {
        let cachedPage = ExploreTimelinePage<LocalExploreTimelineEdge>(
            edges: [],
            pageInfo: ExploreTimelinePageInfo(
                hasPreviousPage: false,
                hasNextPage: true,
                startCursor: "cached-start",
                endCursor: "cached-end"
            )
        )
        let result = try await collectTimelineResult(
            from: stream(
                response: await cachedResponse(),
                terminalError: TerminalNetworkError()
            )
        ) { _ in
            cachedPage
        }

        #expect(result.page?.pageInfo.startCursor == "cached-start")
        #expect(result.page?.pageInfo.endCursor == "cached-end")
        #expect(result.errorMessage == "Explore network request failed")
    }

    @Test("SOC-14: a terminal network failure before any Explore page is rethrown")
    @MainActor
    func terminalNetworkFailureBeforePageIsRethrown() async {
        var thrownError: (any Error)?

        do {
            _ = try await collectTimelineResult(
                from: stream(response: nil, terminalError: TerminalNetworkError())
            ) { _ in
                ExploreTimelinePage<LocalExploreTimelineEdge>(
                    edges: [],
                    pageInfo: ExploreTimelinePageInfo(
                        hasPreviousPage: false,
                        hasNextPage: false,
                        startCursor: nil,
                        endCursor: nil
                    )
                )
            }
        } catch {
            thrownError = error
        }

        #expect(thrownError is TerminalNetworkError)
    }

    private func cachedResponse() async throws -> GraphQLResponse<HackersPub.LocalTimelineQuery> {
        let data = try await HackersPub.LocalTimelineQuery.Data(
            data: [
                "publicTimeline": [
                    "__typename": "QueryPublicTimelineConnection",
                    "edges": [],
                    "pageInfo": [
                        "__typename": "PageInfo",
                        "hasPreviousPage": false,
                        "hasNextPage": true,
                        "startCursor": "cached-start",
                        "endCursor": "cached-end"
                    ]
                ]
            ]
        )
        return GraphQLResponse(
            data: data,
            extensions: nil,
            errors: nil,
            source: .cache,
            dependentKeys: nil
        )
    }

    private func stream(
        response: GraphQLResponse<HackersPub.LocalTimelineQuery>?,
        terminalError: (any Error)?
    ) -> AsyncThrowingStream<GraphQLResponse<HackersPub.LocalTimelineQuery>, any Error> {
        AsyncThrowingStream { continuation in
            if let response {
                continuation.yield(response)
            }
            continuation.finish(throwing: terminalError)
        }
    }

    private struct TerminalNetworkError: LocalizedError {
        var errorDescription: String? {
            "Explore network request failed"
        }
    }
}
