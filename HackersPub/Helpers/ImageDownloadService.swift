import Foundation
import Photos
import UniformTypeIdentifiers
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
    private struct PhotoResource {
        let data: Data
        let uniformTypeIdentifier: String
    }

    static func downloadToPhotoLibrary(from urlString: String) async throws {
        guard let url = URL(string: urlString) else {
            throw ImageDownloadServiceError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw ImageDownloadServiceError.invalidImageData
        }
        let resource = try makePhotoResource(from: image)

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

    private static func makePhotoResource(from image: UIImage) throws -> PhotoResource {
        if imageHasAlpha(image), let pngData = image.pngData() {
            return PhotoResource(data: pngData, uniformTypeIdentifier: UTType.png.identifier)
        }

        if let jpegData = image.jpegData(compressionQuality: 1.0) {
            return PhotoResource(data: jpegData, uniformTypeIdentifier: UTType.jpeg.identifier)
        }

        throw ImageDownloadServiceError.invalidImageData
    }

    private static func imageHasAlpha(_ image: UIImage) -> Bool {
        guard let alphaInfo = image.cgImage?.alphaInfo else { return false }

        switch alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }
}
