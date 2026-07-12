@preconcurrency import Apollo
import ApolloAPI

struct TimelineInitialRequest<Query: GraphQLQuery> {
    let query: Query
    let cachePolicy: CachePolicy.Query.CacheAndNetwork
}

enum TimelineInitialRequestFactory {
    static func publicTimeline() -> TimelineInitialRequest<HackersPub.PublicTimelineQuery> {
        TimelineInitialRequest(
            query: HackersPub.PublicTimelineQuery(after: nil, before: nil, first: 20, last: nil),
            cachePolicy: .cacheAndNetwork
        )
    }

    static func personalTimeline() -> TimelineInitialRequest<HackersPub.PersonalTimelineQuery> {
        TimelineInitialRequest(
            query: HackersPub.PersonalTimelineQuery(after: nil, before: nil, first: 20, last: nil),
            cachePolicy: .cacheAndNetwork
        )
    }

    static func localTimeline() -> TimelineInitialRequest<HackersPub.LocalTimelineQuery> {
        TimelineInitialRequest(
            query: HackersPub.LocalTimelineQuery(after: nil, before: nil, first: 20, last: nil),
            cachePolicy: .cacheAndNetwork
        )
    }
}
