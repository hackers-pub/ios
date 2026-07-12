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
    private let presentation: EngagementListSheetPresentation<ShareActorInfo>
    let emptyTitle: String
    let emptyDescription: String?
    let loadMoreTitle: String

    @Environment(\.dismiss) private var dismiss
    @Environment(NavigationCoordinator.self) private var navigationCoordinator

    init(
        title: String,
        actors: [ShareActorInfo],
        isLoading: Bool = false,
        isLoadingMore: Bool = false,
        errorMessage: String? = nil,
        emptyTitle: String = PostEngagementSheetL10n.sharesEmpty,
        emptyDescription: String? = nil,
        hasMore: Bool = false,
        loadMoreTitle: String = PostEngagementSheetL10n.sharesLoadMore,
        onRetry: (() -> Void)? = nil,
        onLoadMore: (() -> Void)? = nil
    ) {
        self.title = title
        presentation = EngagementListSheetPresentation(
            items: actors,
            isLoading: isLoading,
            errorMessage: errorMessage,
            hasMore: hasMore,
            isLoadingMore: isLoadingMore,
            onRetry: onRetry,
            onLoadMore: onLoadMore
        )
        self.emptyTitle = emptyTitle
        self.emptyDescription = emptyDescription
        self.loadMoreTitle = loadMoreTitle
    }

    init(
        title: String,
        state: EngagementListSheetState<ShareActorInfo>,
        emptyTitle: String = PostEngagementSheetL10n.sharesEmpty,
        emptyDescription: String? = nil,
        loadMoreTitle: String = PostEngagementSheetL10n.sharesLoadMore
    ) {
        self.title = title
        presentation = EngagementListSheetPresentation(state: state)
        self.emptyTitle = emptyTitle
        self.emptyDescription = emptyDescription
        self.loadMoreTitle = loadMoreTitle
    }

    var body: some View {
        NavigationStack {
            List {
                if presentation.isLoadingInitial && presentation.items.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                } else if let errorMessage = presentation.initialErrorMessage, presentation.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        if presentation.canRetryInitial {
                            Button(PostEngagementSheetL10n.retry) {
                                presentation.retryInitial()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .listRowSeparator(.hidden)
                } else if presentation.items.isEmpty {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: "person.2.slash",
                        description: emptyDescription.map(Text.init)
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(presentation.items) { actor in
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

                    if presentation.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    } else if let errorMessage = presentation.paginationErrorMessage {
                        EngagementPaginationErrorFooter(
                            message: errorMessage,
                            onRetry: presentation.retryVisibleError
                        )
                        .listRowSeparator(.hidden)
                    } else if presentation.hasMore {
                        Button(loadMoreTitle) {
                            presentation.loadMore()
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(NSLocalizedString("reaction.action.close", comment: "Close"))
                }
            }
        }
        .onDisappear {
            presentation.cancelPendingLoads()
        }
    }
}

struct QuotesListSheetView<P: PostProtocol & ReactionCapablePostProtocol>: View {
    private let presentation: EngagementListSheetPresentation<P>
    let emptyTitle: String
    let emptyDescription: String?
    let loadMoreTitle: String
    let onPostSelected: ((String) -> Void)?
    let loadingView: (() -> AnyView)?
    let loadingMoreView: (() -> AnyView)?

    init(
        items: [P],
        isLoading: Bool = false,
        errorMessage: String? = nil,
        emptyTitle: String = PostEngagementSheetL10n.quotesEmpty,
        emptyDescription: String? = nil,
        hasMore: Bool = false,
        isLoadingMore: Bool = false,
        loadMoreTitle: String = PostEngagementSheetL10n.quotesLoadMore,
        onRetry: (() -> Void)? = nil,
        onLoadMore: (() -> Void)? = nil,
        onPostSelected: ((String) -> Void)? = nil,
        loadingView: (() -> AnyView)? = nil,
        loadingMoreView: (() -> AnyView)? = nil
    ) {
        presentation = EngagementListSheetPresentation(
            items: items,
            isLoading: isLoading,
            errorMessage: errorMessage,
            hasMore: hasMore,
            isLoadingMore: isLoadingMore,
            onRetry: onRetry,
            onLoadMore: onLoadMore
        )
        self.emptyTitle = emptyTitle
        self.emptyDescription = emptyDescription
        self.loadMoreTitle = loadMoreTitle
        self.onPostSelected = onPostSelected
        self.loadingView = loadingView
        self.loadingMoreView = loadingMoreView
    }

    init(
        state: EngagementListSheetState<P>,
        emptyTitle: String = PostEngagementSheetL10n.quotesEmpty,
        emptyDescription: String? = nil,
        loadMoreTitle: String = PostEngagementSheetL10n.quotesLoadMore,
        onPostSelected: ((String) -> Void)? = nil,
        loadingView: (() -> AnyView)? = nil,
        loadingMoreView: (() -> AnyView)? = nil
    ) {
        presentation = EngagementListSheetPresentation(state: state)
        self.emptyTitle = emptyTitle
        self.emptyDescription = emptyDescription
        self.loadMoreTitle = loadMoreTitle
        self.onPostSelected = onPostSelected
        self.loadingView = loadingView
        self.loadingMoreView = loadingMoreView
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if presentation.isLoadingInitial && presentation.items.isEmpty {
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
                } else if let errorMessage = presentation.initialErrorMessage, presentation.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        if presentation.canRetryInitial {
                            Button(PostEngagementSheetL10n.retry) {
                                presentation.retryInitial()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                } else if presentation.items.isEmpty {
                    ContentUnavailableView(
                        emptyTitle,
                        systemImage: "quote.bubble",
                        description: emptyDescription.map(Text.init)
                    )
                    .padding()
                } else {
                    ForEach(presentation.items, id: \.id) { item in
                        PostView(
                            post: item,
                            showAuthor: true,
                            disableNavigation: true,
                            contentRenderMode: .lightweightText
                        )
                        .allowsHitTesting(false)
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onPostSelected?(item.id)
                                }
                        }
                        Divider()
                            .padding(.horizontal)
                    }

                    if presentation.isLoadingMore {
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
                    } else if let errorMessage = presentation.paginationErrorMessage {
                        EngagementPaginationErrorFooter(
                            message: errorMessage,
                            onRetry: presentation.retryVisibleError
                        )
                    } else if presentation.hasMore {
                        Button(loadMoreTitle) {
                            presentation.loadMore()
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .onDisappear {
            presentation.cancelPendingLoads()
        }
    }
}

private struct EngagementPaginationErrorFooter: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(PostEngagementSheetL10n.paginationFailure)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(PostEngagementSheetL10n.retry) {
                onRetry()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}
