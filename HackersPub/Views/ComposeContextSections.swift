import ApolloAPI
import Kingfisher
import SwiftUI

struct ComposeReplyContextStatusView: View {
    let replyToActor: String?
    let errorMessage: String?
    let isLoading: Bool
    let onRetry: () async -> Void

    var body: some View {
        if let replyToActor {
            HStack {
                Text(
                    String(
                        format: NSLocalizedString(
                            "compose.replyingTo",
                            comment: "Replying to label"
                        ),
                        replyToActor
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
        } else if let errorMessage {
            unavailableContextView(detail: errorMessage)
        } else if isLoading {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(
                    NSLocalizedString(
                        "compose.reply.loadingContext",
                        comment: "Loading reply context"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
        } else {
            unavailableContextView(detail: nil)
        }
    }

    private func unavailableContextView(detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(
                NSLocalizedString(
                    "compose.reply.contextUnavailable",
                    comment: "Reply context unavailable"
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button(NSLocalizedString("common.retry", comment: "Retry button")) {
                Task {
                    await onRetry()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

enum ComposeReplyVisibilityPresentation {
    static func title(
        for visibility: GraphQLEnum<HackersPub.PostVisibility>
    ) -> String {
        switch visibility {
        case .case(.public):
            return NSLocalizedString(
                "compose.visibility.public",
                comment: "Public visibility"
            )
        case .case(.unlisted):
            return NSLocalizedString(
                "compose.visibility.unlisted",
                comment: "Unlisted visibility"
            )
        case .case(.followers):
            return NSLocalizedString(
                "compose.visibility.followers",
                comment: "Followers visibility"
            )
        case .case(.direct):
            return NSLocalizedString(
                "compose.visibility.direct",
                comment: "Direct visibility"
            )
        case .case(.none):
            return NSLocalizedString(
                "compose.reply.contextUnavailable",
                comment: "Reply context unavailable"
            )
        case let .unknown(rawValue):
            return rawValue
        }
    }
}

struct ComposeQuotedPostSection: View {
    let post: HackersPub.PostDetailQuery.Data.Node.AsPost?
    let isLoading: Bool
    let didFailToLoad: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "quote.bubble")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(
                    NSLocalizedString(
                        "compose.quoting",
                        comment: "Quoting indicator title"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
            }

            if isLoading && post == nil {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(
                        NSLocalizedString(
                            "compose.quotingLoading",
                            comment: "Loading quoted post message"
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            } else if let post {
                quotedPostView(post)
            } else if didFailToLoad {
                Text(
                    NSLocalizedString(
                        "compose.quotingUnavailable",
                        comment: "Unable to load quoted post message"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private func quotedPostView(
        _ post: HackersPub.PostDetailQuery.Data.Node.AsPost
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            KFImage(URL(string: post.actor.avatarUrl))
                .placeholder {
                    Color.gray.opacity(0.2)
                }
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                if let name = post.actor.name {
                    HTMLTextView(html: name, font: .caption)
                        .lineLimit(1)
                }
                Text(post.actor.handle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(post.excerpt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.top, 10)
    }
}
