import SwiftUI
import Kingfisher

struct ArticleDetailView<P: PostProtocol>: View {
    let post: P
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Author info
                HStack(spacing: 8) {
                    Button {
                        navigationCoordinator.navigateToProfile(handle: post.actor.handle)
                    } label: {
                        KFImage(URL(string: post.actor.avatarUrl))
                            .placeholder {
                                Color.gray.opacity(0.2)
                            }
                            .resizable()
                            .scaledToFill()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 2) {
                        if let name = post.actor.name {
                            HTMLTextView(html: name, font: .headline)
                        }
                        Text(post.actor.handle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal)

                // Article title
                if let name = post.name {
                    Text(name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                }

                // Published date
                Text(post.published)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                Divider()

                // Full article content
                HTMLContentView(
                    html: post.content,
                    media: post.media.map { MediaItem(url: $0.url, thumbnailUrl: $0.thumbnailUrl, alt: $0.alt, width: $0.width, height: $0.height) }
                )
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Article")
        .navigationBarTitleDisplayMode(.inline)
    }
}
