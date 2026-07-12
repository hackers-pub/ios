import Foundation
@testable import HackersPub
import Testing

struct ActorProfileSupplementalRefreshTests {
    @Test func loadedEmptyTabWithoutACursorRefreshesFromTheFirstNetworkPage() {
        let plan = ActorProfileTabRefreshPlan.resolve(
            itemCount: 0,
            startCursor: nil
        )

        #expect(plan == .firstPage)
    }

    @Test func missingCursorFallsBackToAnAuthoritativeFirstPageEvenWhenRowsExist() {
        let plan = ActorProfileTabRefreshPlan.resolve(
            itemCount: 3,
            startCursor: nil
        )

        #expect(plan == .firstPage)
    }

    @Test func nonemptyTabWithACursorRefreshesByMergingNewerRows() {
        let plan = ActorProfileTabRefreshPlan.resolve(
            itemCount: 3,
            startCursor: "newest"
        )

        #expect(plan == .newer(before: "newest"))
    }

    @Test func notesAndArticlesWireFirstPageReplaceAndNewerMerge() throws {
        let source = try supplementalLoadingSource()
        let notesRefresh = try #require(source.block(after: "func refreshNotes() async"))
        let articlesRefresh = try #require(source.block(after: "func refreshArticles() async"))

        for refresh in [notesRefresh, articlesRefresh] {
            #expect(refresh.contains("ActorProfileTabRefreshPlan.resolve"))
            #expect(refresh.contains("case .firstPage:"))
            #expect(refresh.contains("first: 20"))
            #expect(refresh.contains("application: .replace"))
            #expect(refresh.contains("case let .newer(cursor):"))
            #expect(refresh.contains("before: .some(cursor)"))
            #expect(refresh.contains("application: .prepend"))
            #expect(refresh.contains("cachePolicy: .networkOnly"))
        }
    }

    @Test func refreshErrorsRemainRetryableWhileCancellationIsSilent() throws {
        let source = try supplementalLoadingSource()
        let notesLoad = try #require(source.block(after: "private func loadNotesPage"))
        let articlesLoad = try #require(source.block(after: "private func loadArticlesPage"))

        #expect(notesLoad.contains("catch is CancellationError"))
        #expect(notesLoad.contains("notesPageState.errorMessage = error.localizedDescription"))
        #expect(articlesLoad.contains("catch is CancellationError"))
        #expect(articlesLoad.contains("articlesPageState.errorMessage = error.localizedDescription"))
        #expect(!notesLoad.contains("catch is CancellationError {\n            notes ="))
        #expect(!articlesLoad.contains("catch is CancellationError {\n            articles ="))
    }

    private func supplementalLoadingSource() throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot
                .appendingPathComponent("HackersPub")
                .appendingPathComponent("Views")
                .appendingPathComponent("Profile")
                .appendingPathComponent("ActorProfileSupplementalLoading.swift"),
            encoding: .utf8
        )
    }
}

private extension String {
    func block(after marker: String) -> String? {
        guard let markerRange = range(of: marker) else {
            return nil
        }
        guard let openingBrace = self[markerRange.upperBound...].firstIndex(of: "{") else {
            return nil
        }

        var depth = 0
        var index = openingBrace
        while index < endIndex {
            switch self[index] {
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(self[openingBrace ... index])
                }
            default:
                break
            }
            index = self.index(after: index)
        }
        return nil
    }
}
