import Foundation
import Apollo
import UIKit

struct UploadedMedium: Identifiable, Equatable {
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
    case missingPayload(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return NSLocalizedString("mediaUpload.error.invalidImage", comment: "Invalid image upload error")
        case .invalidInput(let path):
            return String(format: NSLocalizedString("mediaUpload.error.invalidInput", comment: "Invalid input upload error"), path)
        case .notAuthenticated:
            return NSLocalizedString("mediaUpload.error.notAuthenticated", comment: "Media upload not authenticated error")
        case .uploadTargetFailed(let status):
            return String(format: NSLocalizedString("mediaUpload.error.uploadTargetFailed", comment: "Upload target failed error"), status)
        case .missingPayload(let stage):
            return String(format: NSLocalizedString("mediaUpload.error.unexpectedResponse", comment: "Unexpected media upload response"), stage)
        case .server(let message):
            return message
        }
    }
}

actor MediumUploadService {
    static let shared = MediumUploadService()

    private let client: ApolloClient
    private let session: URLSession

    init(client: ApolloClient = apolloClient, session: URLSession = .shared) {
        self.client = client
        self.session = session
    }

    func uploadImageData(_ data: Data) async throws -> UploadedMedium {
        let prepared = try prepareImageData(data)
        let startResponse = try await client.perform(
            mutation: HackersPub.StartMediumUploadMutation(
                contentType: prepared.contentType,
                contentLength: Int32(prepared.data.count)
            )
        )
        if let error = startResponse.errors?.first {
            throw MediumUploadError.server(error.localizedDescription)
        }

        let upload = startResponse.data?.startMediumUpload
        if let invalidInput = upload?.asInvalidInputError {
            throw MediumUploadError.invalidInput(invalidInput.inputPath)
        }
        if upload?.asNotAuthenticatedError != nil {
            throw MediumUploadError.notAuthenticated
        }
        guard let payload = upload?.asStartMediumUploadPayload,
              let uploadURL = URL(string: payload.uploadUrl)
        else {
            throw MediumUploadError.missingPayload("start")
        }

        try await putUploadBody(
            prepared.data,
            to: uploadURL,
            method: payload.method,
            headers: payload.headers.map { ($0.name, $0.value) }
        )

        let finishResponse = try await client.perform(
            mutation: HackersPub.FinishMediumUploadMutation(uploadId: payload.uploadId)
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

    private func prepareImageData(_ data: Data) throws -> (data: Data, contentType: String) {
        guard let image = UIImage(data: data) else {
            throw MediumUploadError.invalidImage
        }
        if let jpeg = image.jpegData(compressionQuality: 0.9) {
            return (jpeg, "image/jpeg")
        }
        throw MediumUploadError.invalidImage
    }

    private func putUploadBody(
        _ data: Data,
        to url: URL,
        method: String,
        headers: [(String, String)]
    ) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = method
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        if request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        }
        request.setValue(String(data.count), forHTTPHeaderField: "Content-Length")

        let (_, response) = try await session.upload(for: request, from: data)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MediumUploadError.missingPayload("upload")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw MediumUploadError.uploadTargetFailed(httpResponse.statusCode)
        }
    }
}
