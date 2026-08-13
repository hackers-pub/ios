import Observation
import SwiftUI

struct ExploreTimelineContent<Edge: ExploreTimelineEdge, Row: View>: View {
    @Bindable var store: ExploreTimelineScopeStore<Edge>
    let dataSource: ExploreTimelineDataSource<Edge>
    let row: (Edge) -> Row
    @State private var shouldRefresh = false
    @State private var requestTask: Task<Void, Never>?
    @State private var requestTaskGeneration: Int?

    var body: some View {
        Group {
            if store.isLoadingInitial, store.edges.isEmpty {
                ProgressView()
            } else if let errorMessage = store.errorMessage, store.edges.isEmpty {
                LoadFailureView(message: errorMessage) {
                    Task {
                        await launch(store.requestRefresh())
                    }
                }
            } else if store.hasLoadedInitial, store.edges.isEmpty {
                ContentUnavailableView(
                    NSLocalizedString("explore.empty.title", comment: "Explore empty timeline title"),
                    systemImage: "sparkles",
                    description: Text(
                        NSLocalizedString("explore.empty.description", comment: "Explore empty timeline description")
                    )
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if store.hasPreviousPage, !store.edges.isEmpty {
                            LoadNewerItemsRow(isLoading: store.isLoadingNewer) {
                                Task {
                                    await launch(store.requestNewerPage())
                                }
                            }
                            Divider()
                        }

                        ForEach(store.edges, id: \.timelineListID) { edge in
                            row(edge)
                                .padding()
                                .id(edge.timelineListID)
                                .onAppear {
                                    guard shouldLoadMore(afterAppearing: edge) else { return }

                                    Task {
                                        await launch(store.requestOlderPage())
                                    }
                                }

                            Divider()
                        }

                        if store.isLoadingOlder, !store.edges.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding()
                        }

                        if let errorMessage = store.errorMessage, !store.edges.isEmpty {
                            InlineLoadFailureView(message: errorMessage) {
                                Task {
                                    await launch(store.requestRefresh())
                                }
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $store.scrollPositionID)
            }
        }
        .refreshable {
            await launch(store.requestRefresh())
        }
        .task {
            await launch(store.startInitialLoadIfNeeded())
        }
        .onDisappear {
            cancelVisibleRequestTask()
            store.cancelVisibleWork()
        }
        .onChange(of: shouldRefresh) { _, newValue in
            guard newValue else { return }

            Task {
                await launch(store.requestRefresh())
                shouldRefresh = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshTimeline"))) { _ in
            shouldRefresh = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .postContentDidChange)) { notification in
            handlePostContentNotification(notification)
        }
    }

    private func shouldLoadMore(afterAppearing edge: Edge) -> Bool {
        store.hasNextPage && !store.isLoading && edge.timelineListID == store.edges.last?.timelineListID
    }

    private func launch(_ request: ExploreTimelineRequest?) async {
        guard let request, store.isCurrent(request) else { return }

        let task = Task {
            await perform(request)
        }
        requestTask = task
        requestTaskGeneration = request.generation
        await task.value

        if requestTaskGeneration == request.generation {
            requestTask = nil
            requestTaskGeneration = nil
        }
    }

    private func perform(_ request: ExploreTimelineRequest?) async {
        guard let request, store.isCurrent(request) else { return }

        guard !Task.isCancelled else {
            await resolve(request, with: .failure(CancellationError()))
            return
        }

        do {
            let response = try await fetchPage(for: request.operation)
            let result: Result<ExploreTimelineFetchResult<Edge>, Error> = Task.isCancelled
                ? .failure(CancellationError())
                : .success(response)
            await resolve(request, with: result)
        } catch {
            await resolve(request, with: .failure(error))
        }
    }

    private func fetchPage(
        for operation: ExploreTimelineRequest.Operation
    ) async throws -> ExploreTimelineFetchResult<Edge> {
        switch operation {
        case .initial:
            try await dataSource.fetchInitial()
        case let .older(cursor):
            try await dataSource.fetchOlder(cursor)
        case let .newer(cursor):
            try await dataSource.fetchNewer(cursor)
        }
    }

    private func resolve(
        _ request: ExploreTimelineRequest,
        with result: Result<ExploreTimelineFetchResult<Edge>, Error>
    ) async {
        let replay = store.resolve(request, with: result)
        await perform(replay)
    }

    @MainActor
    private func handlePostContentNotification(_ notification: Notification) {
        guard let event = PostContentEventCenter.event(from: notification),
              case let .applied(replay) = store.applyPostContentEvent(event)
        else {
            return
        }

        // The store fenced stale completions before this cancellation can resolve.
        cancelVisibleRequestTask()
        guard let replay else { return }

        Task {
            await launch(replay)
        }
    }

    private func cancelVisibleRequestTask() {
        requestTask?.cancel()
        requestTask = nil
        requestTaskGeneration = nil
    }
}
