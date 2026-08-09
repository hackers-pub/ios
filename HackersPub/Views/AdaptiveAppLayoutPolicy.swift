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

struct CompanionToolbarConfiguration {
    let isAvailable: Bool
    let show: () -> Void

    static let unavailable = CompanionToolbarConfiguration(
        isAvailable: false,
        show: {}
    )
}

private struct CompanionToolbarConfigurationKey: EnvironmentKey {
    static let defaultValue = CompanionToolbarConfiguration.unavailable
}

extension EnvironmentValues {
    var feedMaximumWidth: CGFloat? {
        get { self[FeedMaximumWidthKey.self] }
        set { self[FeedMaximumWidthKey.self] = newValue }
    }

    var companionToolbarConfiguration: CompanionToolbarConfiguration {
        get { self[CompanionToolbarConfigurationKey.self] }
        set { self[CompanionToolbarConfigurationKey.self] = newValue }
    }
}

struct NotificationsCompanionToolbarItem: ToolbarContent {
    @Environment(\.companionToolbarConfiguration) private var configuration

    var body: some ToolbarContent {
        if configuration.isAvailable {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: configuration.show) {
                    Label(
                        NSLocalizedString(
                            "notifications.showCompanion",
                            comment: "Show notifications companion"
                        ),
                        systemImage: "sidebar.right"
                    )
                }
                .accessibilityIdentifier("notifications.companion.show")
            }
        }
    }
}
