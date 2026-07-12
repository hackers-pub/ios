import Foundation

enum HTMLMediaLoadState: Equatable {
    case loading
    case loaded
    case failed
}

enum HTMLMediaLoadEvent {
    case succeeded
    case failed
    case retry
}

enum HTMLMediaLoadReducer {
    static func reduce(_ state: HTMLMediaLoadState, event: HTMLMediaLoadEvent) -> HTMLMediaLoadState {
        switch (state, event) {
        case (_, .retry):
            return .loading
        case (.loading, .succeeded):
            return .loaded
        case (.loading, .failed):
            return .failed
        default:
            // A terminal callback cannot replace a result that was already shown.
            return state
        }
    }
}

struct HTMLMediaLoadAttempt: Equatable {
    let id: UUID
    let state: HTMLMediaLoadState

    init(id: UUID = UUID(), state: HTMLMediaLoadState = .loading) {
        self.id = id
        self.state = state
    }

    func applying(_ event: HTMLMediaLoadEvent, from attemptID: UUID) -> Self {
        guard id == attemptID else {
            return self
        }

        return Self(id: id, state: HTMLMediaLoadReducer.reduce(state, event: event))
    }

    func retrying() -> Self {
        Self(
            state: HTMLMediaLoadReducer.reduce(state, event: .retry)
        )
    }
}
