import Foundation
import Photos

enum ImageDownloadServiceError: LocalizedError, Equatable {
    case invalidURL
    case invalidImageData
    case invalidResponse
    case httpStatus(Int)
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("image.download.error.invalidURL", comment: "Invalid image URL")
        case .invalidImageData:
            return NSLocalizedString("image.download.error.invalidData", comment: "Invalid image data")
        case .invalidResponse:
            return NSLocalizedString("image.download.error.invalidResponse", comment: "Invalid image response")
        case let .httpStatus(statusCode):
            let format = NSLocalizedString("image.download.error.httpStatus", comment: "Image download HTTP status")
            return String(format: format, statusCode)
        case .permissionDenied:
            return NSLocalizedString("image.download.error.permissionDenied", comment: "Photo access denied")
        }
    }
}

enum ImageDownloadResponsePolicy {
    static func validate(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse else {
            throw ImageDownloadServiceError.invalidResponse
        }
        guard (200 ..< 300).contains(response.statusCode) else {
            throw ImageDownloadServiceError.httpStatus(response.statusCode)
        }
    }
}

enum ImageDownloadService {
    static func downloadToPhotoLibrary(from urlString: String) async throws {
        guard let url = URL(string: urlString) else {
            throw ImageDownloadServiceError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        try ImageDownloadResponsePolicy.validate(response)
        let resource = try photoResource(from: data)

        let isAuthorized = await requestPhotoLibraryPermissionIfNeeded()
        guard isAuthorized else {
            throw ImageDownloadServiceError.permissionDenied
        }

        try await PHPhotoLibrary.shared().performChanges {
            let creationRequest = PHAssetCreationRequest.forAsset()
            let resourceOptions = PHAssetResourceCreationOptions()
            resourceOptions.uniformTypeIdentifier = resource.uniformTypeIdentifier
            creationRequest.addResource(with: .photo, data: resource.data, options: resourceOptions)
        }
    }

    private static func requestPhotoLibraryPermissionIfNeeded() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return newStatus == .authorized || newStatus == .limited
        default:
            return false
        }
    }

    static func photoResource(from data: Data) throws -> ImagePayload {
        do {
            return try ImagePayloadPolicy.payload(from: data)
        } catch {
            throw ImageDownloadServiceError.invalidImageData
        }
    }
}
