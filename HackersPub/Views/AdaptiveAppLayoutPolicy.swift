import SwiftUI

struct AdaptiveAppLayoutPolicy: Equatable {
    static let minimumCompanionContainerWidth: CGFloat = 1_000
    static let minimumReadableFeedContainerWidth: CGFloat = 900
    static let readableFeedMaximumWidth: CGFloat = 820

    let horizontalSizeClass: UserInterfaceSizeClass?
    let containerWidth: CGFloat
    let isAuthenticated: Bool
    let selectedTab: AppTab
    let isNotificationsCompanionRequested: Bool

    var canOfferNotificationsCompanion: Bool {
        horizontalSizeClass == .regular
            && containerWidth >= Self.minimumCompanionContainerWidth
            && isAuthenticated
    }

    var shouldPresentNotificationsCompanion: Bool {
        canOfferNotificationsCompanion
            && isNotificationsCompanionRequested
            && selectedTab != .notifications
    }

    var feedMaximumWidth: CGFloat? {
        guard horizontalSizeClass == .regular,
              containerWidth >= Self.minimumReadableFeedContainerWidth,
              !shouldPresentNotificationsCompanion
        else {
            return nil
        }
        return Self.readableFeedMaximumWidth
    }
}

private struct FeedMaximumWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

extension EnvironmentValues {
    var feedMaximumWidth: CGFloat? {
        get { self[FeedMaximumWidthKey.self] }
        set { self[FeedMaximumWidthKey.self] = newValue }
    }
}
