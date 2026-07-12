@preconcurrency import Apollo
import SwiftUI

private typealias ActorProfileDestinationActor = HackersPub.ActorByHandleQuery.Data.ActorByHandle

struct ActorProfileViewWrapper: View {
    let handle: String

    @Environment(AuthManager.self) private var authManager
    @State private var actor: ActorProfileDestinationActor?
    @State private var presentation: ActorProfileDestinationPresentation = .idle
    @State private var refreshFailure: ActorProfileDestinationFailure?
    @State private var destinationLoadCoordinator = ActorProfileDestinationLoadCoordinator()

    private var destinationContext: ActorProfileDestinationContext {
        ActorProfileDestinationContext(
            handle: handle,
            accountID: authManager.currentAccount?.id
        )
    }

    var body: some View {
        Group {
            if let actor {
                ActorProfileView(actor: actor)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if let refreshFailure {
                            InlineLoadFailureView(message: refreshFailure.localizedMessage) {
                                retryLatestDestination()
                            }
                        }
                    }
            } else {
                switch presentation {
                case .idle, .loading, .loaded:
                    ProgressView(
                        NSLocalizedString(
                            "profile.destination.loading",
                            comment: "Profile destination loading"
                        )
                    )
                case let .failed(failure):
                    LoadFailureView(message: failure.localizedMessage) {
                        retryLatestDestination()
                    }
                }
            }
        }
        .task(id: destinationContext) {
            await loadProfile(for: destinationContext)
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private func loadProfile(for context: ActorProfileDestinationContext) async {
        let contextChanged = destinationLoadCoordinator.context != context
        let request = destinationLoadCoordinator.begin(context: context)
        if contextChanged {
            actor = nil
            refreshFailure = nil
        }
        if actor == nil {
            presentation = .loading
        } else {
            refreshFailure = nil
        }

        do {
            let response = try await apolloClient.fetch(
                query: HackersPub.ActorByHandleQuery(
                    handle: context.handle,
                    after: nil,
                    before: nil,
                    first: 20,
                    last: nil
                ),
                cachePolicy: .networkOnly
            )
            try Task.checkCancellation()
            guard isCurrent(request, for: context) else {
                return
            }
            if response.errors?.first != nil {
                applyFailure(.graphQL, for: request, context: context)
                return
            }
            guard let actorData = response.data?.actorByHandle else {
                applyFailure(.notFound, for: request, context: context)
                return
            }
            guard context.matches(handle: actorData.handle) else {
                applyFailure(.notFound, for: request, context: context)
                return
            }
            guard destinationLoadCoordinator.finish(request) else {
                return
            }

            actor = actorData
            presentation = .loaded
            refreshFailure = nil
        } catch is CancellationError {
            finishCancellation(for: request, context: context)
        } catch {
            applyFailure(.transport, for: request, context: context)
        }
    }

    private func retryLatestDestination() {
        let context = destinationContext
        Task {
            await loadProfile(for: context)
        }
    }

    private func isCurrent(
        _ request: ActorProfileDestinationRequest,
        for context: ActorProfileDestinationContext
    ) -> Bool {
        destinationLoadCoordinator.isCurrent(request) && destinationContext == context
    }

    private func applyFailure(
        _ failure: ActorProfileDestinationFailure,
        for request: ActorProfileDestinationRequest,
        context: ActorProfileDestinationContext
    ) {
        guard isCurrent(request, for: context),
              destinationLoadCoordinator.finish(request)
        else {
            return
        }

        if actor == nil {
            presentation = .failed(failure)
        } else {
            refreshFailure = failure
        }
    }

    private func finishCancellation(
        for request: ActorProfileDestinationRequest,
        context: ActorProfileDestinationContext
    ) {
        guard isCurrent(request, for: context),
              destinationLoadCoordinator.finish(request)
        else {
            return
        }

        if actor == nil {
            presentation = .idle
        }
    }
}
