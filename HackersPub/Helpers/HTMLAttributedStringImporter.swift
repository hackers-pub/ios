import UIKit

struct HTMLAttributedStringImporter {
    typealias Operation = @MainActor (
        _ cacheKey: String,
        _ html: String,
        _ uiFont: UIFont,
        _ uiColor: UIColor
    ) async throws -> NSAttributedString

    static let production = Self { cacheKey, html, uiFont, uiColor in
        try await HTMLTextRenderer.attributedString(
            cacheKey: cacheKey,
            html: html,
            uiFont: uiFont,
            uiColor: uiColor
        )
    }

    private let operation: Operation

    init(_ operation: @escaping Operation) {
        self.operation = operation
    }

    @MainActor
    func callAsFunction(
        cacheKey: String,
        html: String,
        uiFont: UIFont,
        uiColor: UIColor
    ) async throws -> NSAttributedString {
        try await operation(cacheKey, html, uiFont, uiColor)
    }
}
