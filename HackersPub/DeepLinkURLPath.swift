import Foundation

enum DeepLinkURLPath {
    static func decodedSegments(from url: URL) -> [String] {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let encodedPath = components?.percentEncodedPath ?? ""

        return encodedPath.split(separator: "/").compactMap { encodedSegment in
            let segment = String(encodedSegment)
            let decoded = segment.removingPercentEncoding ?? segment
            return decoded.isEmpty ? nil : decoded
        }
    }
}
