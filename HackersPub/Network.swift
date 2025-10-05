import Foundation
import Apollo
import ApolloAPI

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
            LoggingInterceptor()
        ] + DefaultInterceptorProvider.shared.graphQLInterceptors(for: operation) + [
            AuthInterceptor()
        ]
    }
}

// Configure Apollo client with custom network transport and store
private let url = URL(string: "https://hackers.pub/graphql")!
private let urlSession = URLSession.shared
private let store = ApolloStore()
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
