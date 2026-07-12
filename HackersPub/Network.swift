import Apollo
import ApolloAPI
import ApolloSQLite
import Foundation

/// Authorization interceptor that adds auth token to GraphQL requests
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

/// Custom interceptor provider for Apollo iOS 2.0
struct CustomInterceptorProvider: InterceptorProvider {
    func graphQLInterceptors<Operation: GraphQLOperation>(for operation: Operation) -> [any GraphQLInterceptor] {
        return [AuthInterceptor()] + DefaultInterceptorProvider.shared.graphQLInterceptors(for: operation)
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

struct ApolloCacheConfiguration {
    static let fileName = "apollo_cache.sqlite"
    static let app = ApolloCacheConfiguration(
        fileURL: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(fileName)
    )

    let fileURL: URL?

    func makeNormalizedCache() -> any NormalizedCache {
        guard let fileURL else {
            return InMemoryNormalizedCache()
        }

        do {
            return try makeSQLiteCache(fileURL: fileURL)
        } catch {
            print("Failed to open Apollo SQLite cache, recreating it: \(error)")
            try? FileManager.default.removeItem(at: fileURL)
        }

        do {
            return try makeSQLiteCache(fileURL: fileURL)
        } catch {
            print("Failed to recreate Apollo SQLite cache, falling back to memory cache: \(error)")
            return InMemoryNormalizedCache()
        }
    }

    private func makeSQLiteCache(fileURL: URL) throws -> SQLiteNormalizedCache {
        let database = try ApolloSQLiteDatabase(fileURL: fileURL)
        try database.setJournalMode(mode: .delete)
        return try SQLiteNormalizedCache(database: database, shouldVacuumOnClear: true)
    }
}

protocol ApolloSQLiteFileSystem {
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any]
}

private struct LiveApolloSQLiteFileSystem: ApolloSQLiteFileSystem {
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        try FileManager.default.attributesOfItem(atPath: path)
    }
}

enum ApolloSQLiteCacheMetricError: Error {
    case invalidFileSize(URL)
}

enum ApolloSQLiteCacheMetric {
    static func physicalSize(
        at fileURL: URL,
        fileSystem: any ApolloSQLiteFileSystem = LiveApolloSQLiteFileSystem()
    ) throws -> Int64 {
        let sidecarURLs = ["-wal", "-shm"].map { suffix in
            fileURL.deletingLastPathComponent().appendingPathComponent(fileURL.lastPathComponent + suffix)
        }

        return try ([fileURL] + sidecarURLs).reduce(into: Int64(0)) { total, url in
            total += try fileSize(at: url, fileSystem: fileSystem)
        }
    }

    private static func fileSize(
        at fileURL: URL,
        fileSystem: any ApolloSQLiteFileSystem
    ) throws -> Int64 {
        do {
            let attributes = try fileSystem.attributesOfItem(atPath: fileURL.path)
            guard let size = attributes[.size] as? NSNumber,
                  size.int64Value >= 0
            else {
                throw ApolloSQLiteCacheMetricError.invalidFileSize(fileURL)
            }
            return size.int64Value
        } catch {
            if isMissingFileError(error) {
                return 0
            }
            throw error
        }
    }

    private static func isMissingFileError(_ error: any Error) -> Bool {
        let nsError = error as NSError
        // swiftlint:disable opening_brace
        if nsError.domain == NSCocoaErrorDomain,
           [
               CocoaError.Code.fileNoSuchFile.rawValue,
               CocoaError.Code.fileReadNoSuchFile.rawValue
           ].contains(nsError.code)
        {
            return true
        }
        if nsError.domain == NSPOSIXErrorDomain,
           nsError.code == Int(POSIXErrorCode.ENOENT.rawValue)
        {
            return true
        }
        // swiftlint:enable opening_brace
        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? any Error {
            return isMissingFileError(underlyingError)
        }
        return false
    }
}

/// Create a persistent SQLite cache
private let store = ApolloStore(cache: ApolloCacheConfiguration.app.makeNormalizedCache())

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
