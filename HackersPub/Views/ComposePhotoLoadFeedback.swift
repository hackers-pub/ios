import Foundation

struct ComposePhotoLoadFeedback {
    let omittedForLimitCount: Int
    private(set) var failedCount = 0

    init(omittedForLimitCount: Int) {
        self.omittedForLimitCount = max(0, omittedForLimitCount)
    }

    mutating func recordFailure() {
        failedCount += 1
    }

    func localizedMessage(
        localize: (_ key: String, _ count: Int) -> String = { key, count in
            String(
                format: NSLocalizedString(key, comment: "Photo selection or load count feedback"),
                count
            )
        }
    ) -> String? {
        var messages: [String] = []
        if omittedForLimitCount > 0 {
            messages.append(
                localize("compose.photos.error.limitOmittedCount", omittedForLimitCount)
            )
        }
        if failedCount > 0 {
            messages.append(
                localize("compose.photos.error.loadFailedCount", failedCount)
            )
        }
        return messages.isEmpty ? nil : messages.joined(separator: "\n")
    }
}
