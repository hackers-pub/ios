import Apollo
import Foundation
@testable import HackersPub
import Testing

@MainActor
struct ComposePreparedPublishSettingsTests {
    @Test func manualLanguageAndVisibilityArePreservedInPreparedSettingsAndPersistence() throws {
        let coordinator = ComposeSubmissionCoordinator()
        var settings = ComposePublishSettings(
            language: "en",
            visibility: .case(.public)
        )

        let didSelectLanguage = settings.selectLanguage("ko", isBusy: false)
        let didSelectVisibility = settings.selectVisibility(.case(.followers), isBusy: false)
        #expect(didSelectLanguage)
        #expect(didSelectVisibility)
        settings.applyAutomaticLanguage("en", isBusy: false)

        let prepared = try #require(coordinator.prepareSubmission { revision in
            settings.prepared(content: "manual settings", revision: revision)
        })

        #expect(prepared.value.language == "ko")
        #expect(prepared.value.visibility == .case(.followers))
        #expect(prepared.value.localeToPersist(
            after: .success,
            successfulRevision: prepared.revision,
            comparedTo: "en"
        ) == "ko")
    }

    @Test func delayedUploadUsesOnePreparedSettingsRevisionForMutationAndPersistence() async throws {
        let coordinator = ComposeSubmissionCoordinator()
        let blocker = PreparedSettingsBlocker()
        var settings = ComposePublishSettings(
            language: "en",
            visibility: .case(.public)
        )
        var currentContent = "prepared content"
        var submittedSettings: ComposePreparedPublishSettings?

        let prepared = try #require(coordinator.prepareSubmission { revision in
            settings.prepared(content: currentContent, revision: revision)
        })
        let task = Task {
            try await coordinator.perform(
                prepared,
                upload: { _ in
                    await blocker.run()
                },
                submit: { preparedSettings, _ in
                    submittedSettings = preparedSettings
                    return ComposeNoteSubmissionResult.success
                }
            )
        }

        await blocker.waitUntilStarted()
        currentContent = "edited while uploading"
        let changedLanguage = settings.selectLanguage("ko", isBusy: coordinator.isBusy)
        let changedVisibility = settings.selectVisibility(.case(.followers), isBusy: coordinator.isBusy)

        #expect(!changedLanguage)
        #expect(!changedVisibility)
        #expect(settings.language == "en")
        #expect(settings.visibility == .case(.public))

        blocker.finish()
        let outcome = try await task.value

        guard case .completed(.success) = outcome,
              let submittedSettings
        else {
            Issue.record("The prepared submission did not complete successfully")
            return
        }

        #expect(submittedSettings.content == "prepared content")
        #expect(submittedSettings.language == "en")
        #expect(submittedSettings.visibility == .case(.public))
        #expect(submittedSettings.revision == prepared.revision)
        #expect(prepared.value.localeToPersist(
            after: .success,
            successfulRevision: prepared.revision,
            comparedTo: "ko"
        ) == "en")
    }

    @Test func failureOrMismatchedRevisionNeverPersistsPreparedLanguage() throws {
        let coordinator = ComposeSubmissionCoordinator()
        let settings = ComposePublishSettings(language: "en", visibility: .case(.public))
        let first = try #require(coordinator.prepareSubmission { revision in
            settings.prepared(content: "content", revision: revision)
        })

        #expect(first.value.localeToPersist(
            after: .failed,
            successfulRevision: first.revision,
            comparedTo: "ko"
        ) == nil)

        let otherCoordinator = ComposeSubmissionCoordinator()
        let other = try #require(otherCoordinator.prepareSubmission { revision in revision })
        #expect(first.value.localeToPersist(
            after: .success,
            successfulRevision: other.value,
            comparedTo: "ko"
        ) == nil)
    }
}

@MainActor
private final class PreparedSettingsBlocker {
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var completion: CheckedContinuation<Void, Never>?
    private var hasStarted = false

    func run() async {
        hasStarted = true
        startWaiters.forEach { $0.resume() }
        startWaiters.removeAll()
        await withCheckedContinuation { continuation in
            completion = continuation
        }
    }

    func waitUntilStarted() async {
        guard !hasStarted else { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func finish() {
        completion?.resume()
        completion = nil
    }
}
