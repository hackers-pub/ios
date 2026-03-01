import Kingfisher
import SwiftUI

let supportedReactionEmojis = ["❤️", "🎉", "😂", "😲", "🤔", "😢", "👀"]

enum ReactionL10n {
    static let title = NSLocalizedString("reaction.title", comment: "Reactions title")
    static let react = NSLocalizedString("reaction.action.react", comment: "React action")
    static let failedTitle = NSLocalizedString("reaction.error.title", comment: "Reaction error title")
    static let signInRequired = NSLocalizedString(
        "reaction.error.signInRequired",
        comment: "Sign in required to react message"
    )
    static let unableToAdd = NSLocalizedString(
        "reaction.error.unableToAdd",
        comment: "Unable to add reaction message"
    )
    static let unableToRemove = NSLocalizedString(
        "reaction.error.unableToRemove",
        comment: "Unable to remove reaction message"
    )
    static let close = NSLocalizedString("reaction.action.close", comment: "Close reaction picker")
    static let reactedWithFormat = NSLocalizedString(
        "reaction.reactors.titleFormat",
        comment: "Navigation title format for reacted users list"
    )
}

struct ReactionGroupSnapshot: Identifiable, Hashable {
    let id: String
    let emoji: String?
    let customEmojiName: String?
    let customEmojiImageUrl: String?
    var totalCount: Int
    var viewerHasReacted: Bool
}

protocol ReactionCapablePostProtocol {
    var reactionGroupsSnapshot: [ReactionGroupSnapshot] { get }
}

private func sortReactionGroups(_ groups: [ReactionGroupSnapshot]) -> [ReactionGroupSnapshot] {
    let emojiOrder = Dictionary(uniqueKeysWithValues: supportedReactionEmojis.enumerated().map { ($1, $0) })
    return groups.sorted { lhs, rhs in
        switch (lhs.emoji, rhs.emoji) {
        case let (.some(leftEmoji), .some(rightEmoji)):
            let leftIndex = emojiOrder[leftEmoji] ?? Int.max
            let rightIndex = emojiOrder[rightEmoji] ?? Int.max
            if leftIndex != rightIndex {
                return leftIndex < rightIndex
            }
            return leftEmoji < rightEmoji
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return (lhs.customEmojiName ?? "") < (rhs.customEmojiName ?? "")
        }
    }
}

struct ReactionPickerView: View {
    let reactionGroups: [ReactionGroupSnapshot]
    let isSubmitting: Bool
    let onEmojiSelect: (String) -> Void
    let onClose: () -> Void

    private var standardGroupsByEmoji: [String: ReactionGroupSnapshot] {
        Dictionary(
            uniqueKeysWithValues: reactionGroups.compactMap { group in
                guard let emoji = group.emoji else { return nil }
                return (emoji, group)
            }
        )
    }

    private var sortedGroups: [ReactionGroupSnapshot] {
        sortReactionGroups(reactionGroups)
    }

    private var selectedGroups: [ReactionGroupSnapshot] {
        sortReactionGroups(reactionGroups.filter { $0.viewerHasReacted })
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let selectedBarHeight: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(ReactionL10n.title)
                    .font(.headline)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 30, height: 30)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.28), lineWidth: 0.7)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(ReactionL10n.close)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(supportedReactionEmojis, id: \.self) { emoji in
                    let existingGroup = standardGroupsByEmoji[emoji]
                    Button {
                        onEmojiSelect(emoji)
                    } label: {
                        VStack(spacing: 2) {
                            Text(emoji)
                                .font(.title3)
                            if let count = existingGroup?.totalCount, count > 0 {
                                Text("\(count)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("0")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(existingGroup?.viewerHasReacted == true ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                }
            }

            Divider()

            ZStack(alignment: .leading) {
                if !selectedGroups.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedGroups) { group in
                                Button {
                                    if let emoji = group.emoji {
                                        onEmojiSelect(emoji)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        if let emoji = group.emoji {
                                            Text(emoji)
                                        } else if let imageUrl = group.customEmojiImageUrl, let url = URL(string: imageUrl) {
                                            KFImage(url)
                                                .placeholder {
                                                    Text(group.customEmojiName ?? "?")
                                                        .font(.caption2)
                                                }
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 16, height: 16)
                                        } else {
                                            Text(group.customEmojiName ?? "?")
                                                .font(.caption)
                                        }

                                        Text("\(group.totalCount)")
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor.opacity(0.2))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .disabled(isSubmitting || group.emoji == nil)
                            }
                        }
                    }
                }
            }
            .frame(height: selectedBarHeight)
        }
        .padding()
    }
}

private struct ReactionPickerHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    func trackReactionPickerHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        self
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ReactionPickerHeightPreferenceKey.self,
                        value: proxy.size.height
                    )
                }
            )
            .onPreferenceChange(ReactionPickerHeightPreferenceKey.self, perform: onChange)
    }
}
