import Foundation

@MainActor
struct EngagementListSheetPresentation<Item> {
    private let state: EngagementListSheetState<Item>?
    private let legacyItems: [Item]
    private let legacyIsLoading: Bool
    private let legacyErrorMessage: String?
    private let legacyHasMore: Bool
    private let legacyIsLoadingMore: Bool
    private let legacyRetry: (() -> Void)?
    private let legacyLoadMore: (() -> Void)?

    init(
        items: [Item],
        isLoading: Bool,
        errorMessage: String?,
        hasMore: Bool,
        isLoadingMore: Bool,
        onRetry: (() -> Void)?,
        onLoadMore: (() -> Void)?
    ) {
        state = nil
        legacyItems = items
        legacyIsLoading = isLoading
        legacyErrorMessage = errorMessage
        legacyHasMore = hasMore
        legacyIsLoadingMore = isLoadingMore
        legacyRetry = onRetry
        legacyLoadMore = onLoadMore
    }

    init(state: EngagementListSheetState<Item>) {
        self.state = state
        legacyItems = []
        legacyIsLoading = false
        legacyErrorMessage = nil
        legacyHasMore = false
        legacyIsLoadingMore = false
        legacyRetry = nil
        legacyLoadMore = nil
    }

    var items: [Item] {
        state?.items ?? legacyItems
    }

    var isLoadingInitial: Bool {
        state?.isLoadingInitial ?? legacyIsLoading
    }

    var initialErrorMessage: String? {
        state?.initialErrorMessage ?? legacyErrorMessage
    }

    var paginationErrorMessage: String? {
        if let state {
            return state.paginationErrorMessage ?? (state.items.isEmpty ? nil : state.initialErrorMessage)
        }
        return legacyItems.isEmpty ? nil : legacyErrorMessage
    }

    var hasMore: Bool {
        state?.hasMore ?? legacyHasMore
    }

    var isLoadingMore: Bool {
        state?.isLoadingMore ?? legacyIsLoadingMore
    }

    var canRetryInitial: Bool {
        state != nil || legacyRetry != nil
    }

    func retryInitial() {
        if let state {
            Task {
                await state.retryInitial()
            }
        } else {
            legacyRetry?()
        }
    }

    func retryVisibleError() {
        if let state {
            Task {
                await state.retryVisibleError()
            }
        } else if legacyItems.isEmpty {
            legacyRetry?()
        } else if let legacyLoadMore {
            legacyLoadMore()
        } else {
            legacyRetry?()
        }
    }

    func loadMore() {
        if let state {
            Task {
                await state.loadMore()
            }
        } else {
            legacyLoadMore?()
        }
    }

    func cancelPendingLoads() {
        state?.cancelPendingLoads()
    }
}
