import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ImagePayload: Equatable {
    let data: Data
    let contentType: String
    let uniformTypeIdentifier: String
}

enum ImagePayloadError: Error, Equatable {
    case invalidImage
}

enum ImagePayloadPolicy {
    static func payload(from data: Data) throws -> ImagePayload {
        guard !data.isEmpty,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let typeIdentifier = CGImageSourceGetType(source),
              let type = UTType(typeIdentifier as String),
              type.conforms(to: .image),
              let contentType = type.preferredMIMEType
        else {
            throw ImagePayloadError.invalidImage
        }

        return ImagePayload(
            data: data,
            contentType: contentType,
            uniformTypeIdentifier: type.identifier
        )
    }
}
