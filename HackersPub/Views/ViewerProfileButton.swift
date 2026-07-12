import Kingfisher
import SwiftUI

enum ViewerProfileButtonPresentation: Equatable {
    case hidden
    case placeholder
    case profile(handle: String, avatarURL: String?)

    static func resolve(
        isAuthenticated: Bool,
        handle: String?,
        avatarURL: String?
    ) -> Self {
        guard isAuthenticated else {
            return .hidden
        }

        guard let handle, !handle.isEmpty else {
            return .placeholder
        }

        return .profile(handle: handle, avatarURL: avatarURL)
    }
}

struct ViewerProfileButton: View {
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        switch ViewerProfileButtonPresentation.resolve(
            isAuthenticated: authManager.isAuthenticated,
            handle: authManager.currentAccount?.handle,
            avatarURL: authManager.currentAccount?.avatarUrl
        ) {
        case .hidden:
            EmptyView()

        case .placeholder:
            Image(systemName: "person.crop.circle")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

        case let .profile(handle, avatarURL):
            Button {
                navigationCoordinator.navigateToProfile(handle: handle)
            } label: {
                profileImage(avatarURL: avatarURL)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                NSLocalizedString("profile.viewer.accessibilityLabel", comment: "Viewer profile button")
            )
        }
    }

    @ViewBuilder
    private func profileImage(avatarURL: String?) -> some View {
        if let avatarURL, let url = URL(string: avatarURL) {
            KFImage(url)
                .placeholder {
                    Color.gray.opacity(0.2)
                }
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
        }
    }
}
