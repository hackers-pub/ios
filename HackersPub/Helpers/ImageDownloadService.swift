import Foundation
import Photos
import UIKit

enum ImageDownloadServiceError: LocalizedError {
    case invalidURL
    case invalidImageData
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("image.download.error.invalidURL", comment: "Invalid image URL")
        case .invalidImageData:
            return NSLocalizedString("image.download.error.invalidData", comment: "Invalid image data")
        case .permissionDenied:
            return NSLocalizedString("image.download.error.permissionDenied", comment: "Photo access denied")
        }
    }
}

enum ImageDownloadService {
    static func downloadToPhotoLibrary(from urlString: String) async throws {
        guard let url = URL(string: urlString) else {
            throw ImageDownloadServiceError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw ImageDownloadServiceError.invalidImageData
        }

        let isAuthorized = await requestPhotoLibraryPermissionIfNeeded()
        guard isAuthorized else {
            throw ImageDownloadServiceError.permissionDenied
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
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
}
