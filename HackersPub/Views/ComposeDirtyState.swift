struct ComposeDirtyState: Equatable {
    private(set) var baselineContent: String
    private var hasAppliedReplyMentionSeed = false

    init(initialContent: String) {
        baselineContent = initialContent
    }

    func isContentDirty(currentContent: String) -> Bool {
        currentContent != baselineContent
    }

    mutating func applyReplyMentionSeed(
        handles: [String],
        currentContent: String,
        isCurrent: Bool
    ) -> String {
        guard isCurrent, !hasAppliedReplyMentionSeed else { return currentContent }
        hasAppliedReplyMentionSeed = true

        let mentions = handles.joined(separator: " ")
        guard !mentions.isEmpty else { return currentContent }

        baselineContent = prepending(mentions, to: baselineContent)
        return prepending(mentions, to: currentContent)
    }

    private func prepending(_ mentions: String, to content: String) -> String {
        content.isEmpty ? mentions : "\(mentions) \(content)"
    }
}
