import Apollo
import Foundation

struct UploadedMedium: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let url: String
    let type: String
    let width: Int?
    let height: Int?
}

enum MediumUploadError: LocalizedError {
    case invalidImage
    case invalidInput(String)
    case notAuthenticated
    case uploadTargetFailed(Int)
    case uploadTargetInvalid(Int)
    case fileTooLarge
    case missingPayload(String)
    case checkpointExpired
    case checkpointCorrupt
    case checkpointPersistenceFailed
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return NSLocalizedString("mediaUpload.error.invalidImage", comment: "Invalid image upload error")
        case let .invalidInput(path):
            let format = NSLocalizedString("mediaUpload.error.invalidInput", comment: "Invalid input upload error")
            return String(format: format, path)
        case .notAuthenticated:
            return NSLocalizedString(
                "mediaUpload.error.notAuthenticated",
                comment: "Media upload not authenticated error"
            )
        case let .uploadTargetFailed(status):
            let format = NSLocalizedString(
                "mediaUpload.error.uploadTargetFailed",
                comment: "Upload target failed error"
            )
            return String(format: format, status)
        case let .uploadTargetInvalid(status):
            let format = NSLocalizedString(
                "mediaUpload.error.uploadTargetInvalid",
                comment: "Unusable upload target error"
            )
            return String(format: format, status)
        case .fileTooLarge:
            return NSLocalizedString("mediaUpload.error.fileTooLarge", comment: "Media upload file too large error")
        case let .missingPayload(stage):
            let format = NSLocalizedString(
                "mediaUpload.error.unexpectedResponse",
                comment: "Unexpected media upload response"
            )
            return String(format: format, stage)
        case .checkpointExpired:
            return NSLocalizedString(
                "mediaUpload.error.checkpointExpired",
                comment: "Expired resumable upload checkpoint error"
            )
        case .checkpointCorrupt:
            return NSLocalizedString(
                "mediaUpload.error.checkpointCorrupt",
                comment: "Corrupt resumable upload checkpoint error"
            )
        case .checkpointPersistenceFailed:
            return NSLocalizedString(
                "mediaUpload.error.checkpointPersistenceFailed",
                comment: "Resumable upload checkpoint persistence error"
            )
        case let .server(message):
            return message
        }
    }
}

actor MediumUploadService {
    typealias UploadWaiter = CheckedContinuation<UploadedMedium, any Error>

    enum FlightCompletion {
        case success(UploadedMedium)
        case failure(any Error)
    }

    struct InFlightUpload {
        var waiters: [UUID: UploadWaiter] = [:]
        var cancellationsBeforeRegistration: Set<UUID> = []
    }

    static let shared = MediumUploadService()

    let client: ApolloClient
    private let session: URLSession
    let checkpointStore: any MediumUploadCheckpointStore
    private let scopeProvider: any MediumUploadScopeProviding
    let clock: any MediumUploadClock
    var inFlightUploads: [MediumUploadCheckpointKey: InFlightUpload] = [:]

    init(
        client: ApolloClient = apolloClient,
        session: URLSession = .shared,
        checkpointStore: (any MediumUploadCheckpointStore)? = nil,
        scopeProvider: any MediumUploadScopeProviding = LiveMediumUploadScopeProvider(),
        clock: any MediumUploadClock = SystemMediumUploadClock()
    ) {
        self.client = client
        self.session = session
        self.checkpointStore = checkpointStore ?? FileMediumUploadCheckpointStore(clock: clock)
        self.scopeProvider = scopeProvider
        self.clock = clock
    }

    func uploadImageData(_ data: Data) async throws -> UploadedMedium {
        let prepared = try prepareImageData(data)
        let contentLength = try validatedContentLength(for: prepared.data)
        let scope = try await scopeProvider.currentScope()
        guard scope.isValid else {
            throw MediumUploadError.notAuthenticated
        }
        let checkpointKey = MediumUploadCheckpointKey(
            scope: scope,
            contentType: prepared.contentType,
            data: prepared.data
        )
        try Task.checkCancellation()

        if inFlightUploads[checkpointKey] != nil {
            return try await waitForInFlightUpload(key: checkpointKey)
        }
        inFlightUploads[checkpointKey] = InFlightUpload()

        do {
            let medium = try await performUpload(
                prepared: prepared,
                contentLength: contentLength,
                checkpointKey: checkpointKey
            )
            completeFlight(key: checkpointKey, completion: .success(medium))
            return medium
        } catch {
            completeFlight(key: checkpointKey, completion: .failure(error))
            throw error
        }
    }

    private func prepareImageData(_ data: Data) throws -> ImagePayload {
        do {
            return try ImagePayloadPolicy.payload(from: data)
        } catch {
            throw MediumUploadError.invalidImage
        }
    }

    private func validatedContentLength(for data: Data) throws -> Int32 {
        guard let contentLength = MediumUploadRetryPolicy.contentLength(for: data.count) else {
            throw MediumUploadError.fileTooLarge
        }
        return contentLength
    }

    func finishUpload(id: String) async throws -> UploadedMedium {
        for attempt in 0 ..< MediumUploadRetryPolicy.maximumAttempts {
            try Task.checkCancellation()

            do {
                return try await finishUploadAttempt(id: id)
            } catch {
                guard !Task.isCancelled,
                      !(error is CancellationError),
                      MediumUploadRetryPolicy.shouldRetryFinish(error: error, attempt: attempt)
                else {
                    throw error
                }
                try await Task.sleep(nanoseconds: UInt64(attempt + 1) * 250_000_000)
            }
        }

        throw MediumUploadError.missingPayload("finish")
    }

    private func finishUploadAttempt(id: String) async throws -> UploadedMedium {
        let finishResponse = try await client.perform(
            mutation: HackersPub.FinishMediumUploadMutation(uploadId: id)
        )
        if let error = finishResponse.errors?.first {
            throw MediumUploadError.server(error.localizedDescription)
        }
        let finish = finishResponse.data?.finishMediumUpload
        if let invalidInput = finish?.asInvalidInputError {
            throw MediumUploadError.invalidInput(invalidInput.inputPath)
        }
        if finish?.asNotAuthenticatedError != nil {
            throw MediumUploadError.notAuthenticated
        }
        guard let medium = finish?.asFinishMediumUploadPayload?.medium else {
            throw MediumUploadError.missingPayload("finish")
        }
        return UploadedMedium(
            id: medium.uuid,
            url: medium.url,
            type: medium.type,
            width: medium.width,
            height: medium.height
        )
    }

    func putUploadBody(
        _ data: Data,
        to url: URL,
        method: String,
        headers: [(String, String)],
        contentType: String,
        beforeAttempt: (() async throws -> Void)? = nil
    ) async throws {
        for attempt in 0 ..< MediumUploadRetryPolicy.maximumAttempts {
            do {
                if let beforeAttempt {
                    try await beforeAttempt()
                }
                var request = URLRequest(url: url)
                request.httpMethod = method
                for (name, value) in headers {
                    request.setValue(value, forHTTPHeaderField: name)
                }
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue(contentType, forHTTPHeaderField: "Content-Type")
                }
                request.setValue(String(data.count), forHTTPHeaderField: "Content-Length")

                let (_, response) = try await session.upload(for: request, from: data)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw MediumUploadError.missingPayload("upload")
                }
                guard (200 ..< 300).contains(httpResponse.statusCode) else {
                    throw MediumUploadError.uploadTargetFailed(httpResponse.statusCode)
                }
                return
            } catch {
                guard MediumUploadRetryPolicy.shouldRetry(error: error, attempt: attempt) else {
                    throw error
                }
                try await Task.sleep(nanoseconds: UInt64(attempt + 1) * 250_000_000)
            }
        }

        throw MediumUploadError.missingPayload("upload")
    }
}
