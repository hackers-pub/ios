import Kingfisher
import SwiftUI

struct ShareActorInfo: Identifiable, Hashable {
    let id: String
    let name: String?
    let handle: String
    let avatarUrl: String
}

struct SharesListSheetView: View {
    let title: String
    let actors: [ShareActorInfo]
    let isLoading: Bool
    let isLoadingMore: Bool
    let errorMessage: String?
    let emptyTitle: String
    let emptyDescription: String?
    let hasMore: Bool
    let loadMoreTitle: String
    let onRetry: (() -> Void)?
    let onLoadMore: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    init(
        title: String,
        actors: [ShareActorInfo],
        isLoading: Bool = false,
        isLoadingMore: Bool = false,
        errorMessage: String? = nil,
        emptyTitle: String = "No shares yet",
        emptyDescription: String? = nil,
        hasMore: Bool = false,
        loadMoreTitle: String = "Load more",
        onRetry: (() -> Void)? = nil,
        onLoadMore: (() -> Void)? = nil
    ) {
        self.title = title
        self.actors = actors
        self.isLoading = isLoading
        self.isLoadingMore = isLoadingMore
        self.errorMessage = errorMessage
        self.emptyTitle = emptyTitle
        self.emptyDescription = emptyDescription
        self.hasMore = hasMore
        self.loadMoreTitle = loadMoreTitle
        self.onRetry = onRetry
        self.onLoadMore = onLoadMore
    }

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        if let onRetry {
                            Button("Retry") {
                                onRetry()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .listRowSeparator(.hidden)
                } else if actors.isEmpty {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: "person.2.slash",
                        description: emptyDescription.map(Text.init)
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(actors) { actor in
                        Button {
                            dismiss()
                            navigationCoordinator.navigateToProfile(handle: actor.handle)
                        } label: {
                            HStack(spacing: 12) {
                                KFImage(URL(string: actor.avatarUrl))
                                    .placeholder {
                                        Color.gray.opacity(0.2)
                                    }
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    if let name = actor.name {
                                        HTMLTextView(html: name, font: .subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    Text(actor.handle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    } else if hasMore, let onLoadMore {
                        Button(loadMoreTitle) {
                            onLoadMore()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("settings.done", comment: "Done button")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct QuotesListSheetView<P: PostProtocol & ReactionCapablePostProtocol>: View {
    let items: [P]
    let isLoading: Bool
    let errorMessage: String?
    let emptyTitle: String
    let emptyDescription: String?
    let hasMore: Bool
    let isLoadingMore: Bool
    let loadMoreTitle: String
    let onRetry: (() -> Void)?
    let onLoadMore: (() -> Void)?
    let loadingView: (() -> AnyView)?
    let loadingMoreView: (() -> AnyView)?

    init(
        items: [P],
        isLoading: Bool = false,
        errorMessage: String? = nil,
        emptyTitle: String = "No quotes yet",
        emptyDescription: String? = nil,
        hasMore: Bool = false,
        isLoadingMore: Bool = false,
        loadMoreTitle: String = "Load more",
        onRetry: (() -> Void)? = nil,
        onLoadMore: (() -> Void)? = nil,
        loadingView: (() -> AnyView)? = nil,
        loadingMoreView: (() -> AnyView)? = nil
    ) {
        self.items = items
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.emptyTitle = emptyTitle
        self.emptyDescription = emptyDescription
        self.hasMore = hasMore
        self.isLoadingMore = isLoadingMore
        self.loadMoreTitle = loadMoreTitle
        self.onRetry = onRetry
        self.onLoadMore = onLoadMore
        self.loadingView = loadingView
        self.loadingMoreView = loadingMoreView
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isLoading && items.isEmpty {
                    if let loadingView {
                        loadingView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding()
                    }
                } else if let errorMessage, items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        if let onRetry {
                            Button("Retry") {
                                onRetry()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                } else if items.isEmpty {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: "quote.bubble",
                        description: emptyDescription.map(Text.init)
                    )
                    .padding()
                } else {
                    ForEach(items, id: \.id) { item in
                        PostView(post: item, showAuthor: true, disableNavigation: false)
                            .padding(.horizontal)
                            .padding(.vertical, 12)

                        Divider()
                            .padding(.horizontal)
                    }

                    if isLoadingMore {
                        if let loadingMoreView {
                            loadingMoreView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding()
                        }
                    } else if hasMore, let onLoadMore {
                        Button(loadMoreTitle) {
                            onLoadMore()
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }
}
