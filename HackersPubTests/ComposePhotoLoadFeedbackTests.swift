import Foundation
@testable import HackersPub
import Testing

struct ComposePhotoLoadFeedbackTests {
    @Test func omittedAndFailedCountsUseSeparateKeysInOneMessage() {
        var feedback = ComposePhotoLoadFeedback(omittedForLimitCount: 4)
        feedback.recordFailure()
        feedback.recordFailure()
        var localizedRequests: [String] = []

        let message = feedback.localizedMessage { key, count in
            localizedRequests.append("\(key)=\(count)")
            return "\(key):\(count)"
        }

        #expect(
            localizedRequests == [
                "compose.photos.error.limitOmittedCount=4",
                "compose.photos.error.loadFailedCount=2"
            ]
        )
        #expect(
            message == "compose.photos.error.limitOmittedCount:4\ncompose.photos.error.loadFailedCount:2"
        )
    }

    @Test func successfulUntruncatedLoadHasNoFeedback() {
        let feedback = ComposePhotoLoadFeedback(omittedForLimitCount: 0)

        #expect(feedback.localizedMessage { _, _ in "unexpected" } == nil)
    }

    @Test func englishAndKoreanLocalizeBothPhotoFeedbackCounts() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        for language in ["en", "ko"] {
            let stringsURL = repositoryRoot
                .appendingPathComponent("HackersPub")
                .appendingPathComponent("\(language).lproj")
                .appendingPathComponent("Localizable.strings")
            let strings = try String(contentsOf: stringsURL, encoding: .utf8)

            #expect(strings.contains("\"compose.photos.error.limitOmittedCount\""))
            #expect(strings.contains("\"compose.photos.error.loadFailedCount\""))
        }
    }
}
