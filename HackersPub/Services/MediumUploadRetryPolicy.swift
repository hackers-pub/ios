import Apollo
import Foundation

enum MediumUploadRetryPolicy {
    static let maximumAttempts = 3

    static func contentLength(for byteCount: Int) -> Int32? {
        Int32(exactly: byteCount)
    }

    static func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt + 1 < maximumAttempts else {
            return false
        }

        return isTransient(error)
    }

    static func shouldRetryFinish(error: Error, attempt: Int) -> Bool {
        guard attempt + 1 < maximumAttempts else {
            return false
        }

        return isTransient(error)
    }

    static func shouldRetainPendingFinish(after error: Error) -> Bool {
        error is CancellationError || isTransient(error)
    }

    static func nonReusableUploadTargetStatus(for error: Error) -> Int? {
        guard case let MediumUploadError.uploadTargetFailed(statusCode) = error,
              (400 ... 499).contains(statusCode),
              !isTransientHTTPStatus(statusCode)
        else {
            return nil
        }
        return statusCode
    }

    private static func isTransient(_ error: Error) -> Bool {
        if let responseCodeError = error as? ResponseCodeInterceptor.ResponseCodeError {
            return isTransientHTTPStatus(responseCodeError.response.statusCode)
        }

        if case let MediumUploadError.uploadTargetFailed(statusCode) = error {
            return isTransientHTTPStatus(statusCode)
        }

        guard let urlError = error as? URLError else {
            return false
        }

        switch urlError.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet,
             .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    private static func isTransientHTTPStatus(_ statusCode: Int) -> Bool {
        statusCode == 408 || statusCode == 425 || statusCode == 429 ||
            (500 ... 599).contains(statusCode)
    }
}
