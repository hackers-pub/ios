import SwiftUI
import Kingfisher

struct ViewerProfileButton: View {
    @Environment(NavigationCoordinator.self) private var navigationCoordinator
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        if authManager.isAuthenticated, let viewer = authManager.currentAccount {
            Button {
                navigationCoordinator.navigateToProfile(handle: viewer.handle)
            } label: {
                KFImage(URL(string: viewer.avatarUrl))
                    .placeholder {
                        Color.gray.opacity(0.2)
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
}
