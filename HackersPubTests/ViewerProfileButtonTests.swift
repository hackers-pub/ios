import Foundation
@testable import HackersPub
import Testing

struct ViewerProfileButtonTests {
    @Test func presentationHidesOnlyForGuestsAndKeepsAuthenticatedToolbarSpaceStable() {
        #expect(
            ViewerProfileButtonPresentation.resolve(
                isAuthenticated: false,
                handle: "@viewer@example.com",
                avatarURL: "https://example.com/avatar.png"
            ) == .hidden
        )
        #expect(
            ViewerProfileButtonPresentation.resolve(
                isAuthenticated: true,
                handle: nil,
                avatarURL: nil
            ) == .placeholder
        )
        #expect(
            ViewerProfileButtonPresentation.resolve(
                isAuthenticated: true,
                handle: "@viewer@example.com",
                avatarURL: nil
            ) == .profile(handle: "@viewer@example.com", avatarURL: nil)
        )
    }

    @Test func buttonUsesPresentationStateAndAVisibleAccessibilityLabel() throws {
        let source = try source(named: "ViewerProfileButton.swift")

        #expect(source.contains("ViewerProfileButtonPresentation.resolve("))
        #expect(source.contains("person.crop.circle"))
        #expect(source.contains(".accessibilityLabel("))
        #expect(source.contains("profile.viewer.accessibilityLabel"))
    }

    @Test func searchDetailViewHasNoRemainingDefinitionAndProfileLabelIsLocalized() throws {
        let searchSource = try source(named: "SearchView.swift")
        #expect(!searchSource.contains("struct SearchDetailView"))

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        for locale in ["en", "ko"] {
            let strings = try String(
                contentsOf: repositoryRoot.appendingPathComponent("HackersPub/\(locale).lproj/Localizable.strings"),
                encoding: .utf8
            )
            #expect(strings.contains("\"profile.viewer.accessibilityLabel\""))
        }
    }

    private func source(named filename: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent("HackersPub/Views/\(filename)"),
            encoding: .utf8
        )
    }
}
