import SwiftUI

enum TimelineFeedPresentationPhase: Equatable {
    case initialLoading
    case emptyError(String)
    case empty
    case content
}

struct TimelineFeedPresentationState: Equatable {
    let phase: TimelineFeedPresentationPhase
    let showsLoadNewer: Bool
    let isLoadingNewer: Bool
    let isLoadingMore: Bool
    let inlineErrorMessage: String?

    init(timelineState: TimelineState<some Any>) {
        if timelineState.isInitialLoading && timelineState.edges.isEmpty {
            phase = .initialLoading
        } else if let errorMessage = timelineState.errorMessage, timelineState.edges.isEmpty {
            phase = .emptyError(errorMessage)
        } else if timelineState.edges.isEmpty {
            phase = .empty
        } else {
            phase = .content
        }

        showsLoadNewer = timelineState.hasPreviousPage
        isLoadingNewer = timelineState.isLoadingNewer
        isLoadingMore = timelineState.isLoadingMore
        inlineErrorMessage = timelineState.edges.isEmpty ? nil : timelineState.errorMessage
    }
}

struct TimelineFeedContent<Edge, Post: PostProtocol & ReactionCapablePostProtocol, Sharer: ActorProtocol>: View {
    let timelineState: TimelineState<Edge>
    @Binding var scrollPositionID: String?
    let edgeID: KeyPath<Edge, String>
    let edgeCursor: KeyPath<Edge, String>
    let post: (Edge) -> Post
    let sharer: (Edge) -> Sharer?
    let added: (Edge) -> String?
    let retry: () -> Void
    let refresh: () async -> Void
    let loadNewer: () -> Void
    let loadMore: () -> Void

    private var presentation: TimelineFeedPresentationState {
        TimelineFeedPresentationState(timelineState: timelineState)
    }

    var body: some View {
        switch presentation.phase {
        case .initialLoading:
            ProgressView()
        case let .emptyError(errorMessage):
            LoadFailureView(message: errorMessage, retry: retry)
        case .empty:
            TimelineEmptyState(retry: retry, refresh: refresh)
        case .content:
            content
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if presentation.showsLoadNewer {
                    LoadNewerItemsRow(isLoading: presentation.isLoadingNewer, action: loadNewer)
                    Divider()
                }

                ForEach(timelineState.edges, id: edgeID) { edge in
                    PostView(
                        post: post(edge),
                        timelineSharer: sharer(edge),
                        timelineAdded: added(edge),
                        showAuthor: true,
                        enableSneakPeek: true,
                        contentRenderMode: .lightweightText
                    )
                    .padding()
                    .onAppear {
                        let lastCursor = timelineState.edges.last?[keyPath: edgeCursor]
                        let isLastVisibleEdge = edge[keyPath: edgeCursor] == lastCursor
                        if isLastVisibleEdge, timelineState.canLoadMore {
                            loadMore()
                        }
                    }

                    Divider()
                }

                if presentation.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                }

                if let errorMessage = presentation.inlineErrorMessage {
                    InlineLoadFailureView(message: errorMessage, retry: retry)
                }
            }
            .padding(.top, 8)
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrollPositionID)
        .refreshable {
            await refresh()
        }
    }
}
