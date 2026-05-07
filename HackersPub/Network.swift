import Foundation
import Apollo
import ApolloAPI
import ApolloSQLite

// Authorization interceptor that adds auth token to GraphQL requests
struct AuthInterceptor: GraphQLInterceptor {
    func intercept<Request: GraphQLRequest>(
        request: Request,
        next: NextInterceptorFunction<Request>
    ) async throws -> InterceptorResultStream<Request> {
        var modifiedRequest = request

        // Get token from AuthManager on main actor
        if let token = await AuthManager.shared.sessionToken {
            modifiedRequest.additionalHeaders["Authorization"] = "Bearer \(token)"
        }

        // Proceed to next interceptor with modified request
        return await next(modifiedRequest)
    }
}

// Logging interceptor that prints GraphQL request info
struct LoggingInterceptor: GraphQLInterceptor {
    func intercept<Request: GraphQLRequest>(
        request: Request,
        next: NextInterceptorFunction<Request>
    ) async throws -> InterceptorResultStream<Request> {
        let operationName = String(describing: Request.Operation.self)

        // Only log for PostDetailQuery
        if operationName.contains("PostDetailQuery") {
            print("🟢 ===== GraphQL Request: \(operationName) =====")
        }

        return await next(request)
    }
}

// Custom interceptor provider for Apollo iOS 2.0
struct CustomInterceptorProvider: InterceptorProvider {
    func graphQLInterceptors<Operation: GraphQLOperation>(for operation: Operation) -> [any GraphQLInterceptor] {
        return [
            LoggingInterceptor(),
            AuthInterceptor()
        ] + DefaultInterceptorProvider.shared.graphQLInterceptors(for: operation)
    }
}

// Configure Apollo client with custom network transport and persistent SQLite store
private let url = URL(string: "https://hackers.pub/graphql")!
private let urlSession: URLSession = {
    // Use a dedicated session that bypasses local HTTP response caching so
    // pull-to-refresh always fetches fresh timeline data from the network.
    let configuration = URLSessionConfiguration.ephemeral
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.urlCache = nil
    configuration.httpAdditionalHeaders = [
        "Cache-Control": "no-cache",
        "Pragma": "no-cache"
    ]
    return URLSession(configuration: configuration)
}()

// Create a persistent SQLite cache
private let store = ApolloStore(cache: makeNormalizedCache())

private func makeNormalizedCache() -> any NormalizedCache {
    guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return InMemoryNormalizedCache()
    }

    let sqliteFileURL = documentsURL.appendingPathComponent("apollo_cache.sqlite")

    do {
        return try SQLiteNormalizedCache(fileURL: sqliteFileURL)
    } catch {
        print("Failed to open Apollo SQLite cache, recreating it: \(error)")
        try? FileManager.default.removeItem(at: sqliteFileURL)
    }

    do {
        return try SQLiteNormalizedCache(fileURL: sqliteFileURL)
    } catch {
        print("Failed to recreate Apollo SQLite cache, falling back to memory cache: \(error)")
        return InMemoryNormalizedCache()
    }
}

private let networkTransport = RequestChainNetworkTransport(
    urlSession: urlSession,
    interceptorProvider: CustomInterceptorProvider(),
    store: store,
    endpointURL: url
)

let apolloClient = ApolloClient(
    networkTransport: networkTransport,
    store: store
)

extension ApolloClient {
    func fetchAfterClearingCache<Query: GraphQLQuery>(
        query: Query
    ) async throws -> GraphQLResponse<Query> where Query.ResponseFormat == SingleResponseFormat {
        try await clearCache()
        return try await fetch(query: query, cachePolicy: .networkOnly)
    }
}
