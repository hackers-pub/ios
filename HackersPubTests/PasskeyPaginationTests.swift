import Foundation
@testable import HackersPub
import Testing

@MainActor
struct PasskeyPaginationTests {
    @Test func accumulatesCredentialsAcrossPages() async throws {
        var requestedCursors: [String?] = []
        let firstPage = PasskeyPage(
            passkeys: (0 ..< 50).map { passkey(id: "passkey-\($0)") },
            hasNextPage: true,
            endCursor: "cursor-50"
        )
        let secondPage = PasskeyPage(
            passkeys: [passkey(id: "passkey-50")],
            hasNextPage: false,
            endCursor: "cursor-51"
        )

        let result = try await loadAllPasskeys(
            expectedSessionToken: "session-a",
            currentSessionToken: { "session-a" },
            fetchPage: { cursor in
                requestedCursors.append(cursor)
                return cursor == nil ? firstPage : secondPage
            }
        )

        #expect(result == .loaded(firstPage.passkeys + secondPage.passkeys))
        #expect(requestedCursors == [nil, "cursor-50"])
    }

    @Test func authManagerPreservesExistingListAndPresentsFailureFromSecondPage() async {
        let existingPasskey = passkey(id: "existing")
        var requestCount = 0
        let manager = AuthManager(
            authenticatedSessionToken: "session-a",
            initialPasskeys: [existingPasskey]
        ) { _ in
            requestCount += 1
            if requestCount == 2 {
                throw PasskeyPaginationError.requestFailed("second page failed")
            }
            return PasskeyPage(
                passkeys: [self.passkey(id: "new")],
                hasNextPage: true,
                endCursor: "cursor-new"
            )
        }

        await manager.loadPasskeys()

        #expect(requestCount == 2)
        #expect(manager.passkeys == [existingPasskey])
        #expect(
            manager.passkeysLoadError == NSLocalizedString(
                "settings.passkeys.loadFailed",
                comment: "Passkey list load failure"
            )
        )
        #expect(manager.passkeyListLoadState == .failed)
        #expect(!manager.isLoadingPasskeys)
    }

    @Test func doesNotCommitPagesWhenSessionChangesBetweenPages() async throws {
        var currentSessionToken = "session-a"
        var requestCount = 0

        let result = try await loadAllPasskeys(
            expectedSessionToken: "session-a",
            currentSessionToken: { currentSessionToken },
            fetchPage: { _ in
                requestCount += 1
                currentSessionToken = "session-b"
                return PasskeyPage(
                    passkeys: [passkey(id: "new")],
                    hasNextPage: true,
                    endCursor: "cursor-new"
                )
            }
        )

        #expect(result == .discardedForSessionChange)
        #expect(requestCount == 1)
    }

    @Test func authManagerRejectsANonProgressingCursorWithoutReplacingVisibleRows() async {
        let existingPasskey = passkey(id: "existing")
        var requestCount = 0
        let manager = AuthManager(
            authenticatedSessionToken: "session-a",
            initialPasskeys: [existingPasskey]
        ) { _ in
            requestCount += 1
            return PasskeyPage(
                passkeys: [self.passkey(id: "new-\(requestCount)")],
                hasNextPage: true,
                endCursor: "repeated-cursor"
            )
        }

        await manager.loadPasskeys()

        #expect(requestCount == 2)
        #expect(manager.passkeys == [existingPasskey])
        #expect(
            manager.passkeysLoadError == NSLocalizedString(
                "settings.passkeys.loadFailed",
                comment: "Passkey list load failure"
            )
        )
        #expect(manager.passkeyListLoadState == .failed)
        #expect(!manager.isLoadingPasskeys)
    }

    @Test func authManagerStablyDeduplicatesPasskeysAcrossPages() async {
        var requestedCursors: [String?] = []
        let manager = AuthManager(authenticatedSessionToken: "session-a") { cursor in
            requestedCursors.append(cursor)
            if cursor == nil {
                return PasskeyPage(
                    passkeys: [self.passkey(id: "a"), self.passkey(id: "b")],
                    hasNextPage: true,
                    endCursor: "next"
                )
            }
            return PasskeyPage(
                passkeys: [self.passkey(id: "b"), self.passkey(id: "c")],
                hasNextPage: false,
                endCursor: nil
            )
        }

        await manager.loadPasskeys()

        #expect(requestedCursors == [nil, "next"])
        #expect(manager.passkeys.map(\.id) == ["a", "b", "c"])
        #expect(manager.passkeysLoadError == nil)
    }

    @Test func latestAuthManagerLoadOwnsRowsErrorAndLoadingState() async {
        let loader = ControlledPasskeyPageLoader()
        let manager = AuthManager(
            authenticatedSessionToken: "session-a",
            initialPasskeys: [passkey(id: "existing")],
            passkeyPageLoader: loader.load
        )

        let staleLoad = Task { @MainActor in
            await manager.loadPasskeys()
        }
        await loader.waitForRequestCount(1)

        let latestLoad = Task { @MainActor in
            await manager.loadPasskeys()
        }
        await loader.waitForRequestCount(2)
        #expect(manager.isLoadingPasskeys)

        loader.succeed(
            request: 1,
            with: PasskeyPage(
                passkeys: [passkey(id: "latest")],
                hasNextPage: false,
                endCursor: nil
            )
        )
        await latestLoad.value

        #expect(manager.passkeys.map(\.id) == ["latest"])
        #expect(manager.passkeysLoadError == nil)
        #expect(!manager.isLoadingPasskeys)

        loader.fail(
            request: 0,
            with: PasskeyPaginationError.requestFailed("stale failure")
        )
        await staleLoad.value

        #expect(manager.passkeys.map(\.id) == ["latest"])
        #expect(manager.passkeysLoadError == nil)
        #expect(!manager.isLoadingPasskeys)
    }

    @Test func authManagerTreatsCancellationAsSilentAndPreservesRows() async {
        let existingPasskey = passkey(id: "existing")
        let manager = AuthManager(
            authenticatedSessionToken: "session-a",
            initialPasskeys: [existingPasskey]
        ) { _ in
            throw CancellationError()
        }

        await manager.loadPasskeys()

        #expect(manager.passkeys == [existingPasskey])
        #expect(manager.passkeysLoadError == nil)
        #expect(!manager.isLoadingPasskeys)
    }

    @Test func passkeyLoadFailureIsLocalizedInEverySupportedLocale() throws {
        let expectedMessages = [
            "en": "Unable to load passkeys. Please try again.",
            "ko": "패스키를 불러오지 못했습니다. 다시 시도해 주세요."
        ]

        for (language, expectedMessage) in expectedMessages {
            let strings = try localizedStrings(language: language)
            let message = try #require(strings["settings.passkeys.loadFailed"])

            #expect(message == expectedMessage)
            #expect(message != "settings.passkeys.loadFailed")
        }
    }

    private func localizedStrings(language: String) throws -> [String: String] {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let stringsURL = repositoryRoot
            .appendingPathComponent("HackersPub")
            .appendingPathComponent("\(language).lproj")
            .appendingPathComponent("Localizable.strings")
        let data = try Data(contentsOf: stringsURL)
        let propertyList = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )
        return try #require(propertyList as? [String: String])
    }

    private func passkey(id: String) -> PasskeyInfo {
        PasskeyInfo(id: id, name: id, created: "2026-01-01T00:00:00Z", lastUsed: nil)
    }
}

@MainActor
private final class ControlledPasskeyPageLoader {
    private var continuations: [CheckedContinuation<PasskeyPage, any Error>] = []
    private(set) var requestedCursors: [String?] = []

    func load(cursor: String?) async throws -> PasskeyPage {
        requestedCursors.append(cursor)
        return try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func waitForRequestCount(_ count: Int) async {
        while requestedCursors.count < count {
            await Task.yield()
        }
    }

    func succeed(request: Int, with page: PasskeyPage) {
        continuations[request].resume(returning: page)
    }

    func fail(request: Int, with error: any Error) {
        continuations[request].resume(throwing: error)
    }
}
