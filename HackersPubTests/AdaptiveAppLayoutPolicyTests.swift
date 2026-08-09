import SwiftUI
import Testing
@testable import HackersPub

struct AdaptiveAppLayoutPolicyTests {
    @Test func notificationsCompanionRequiresEveryEligibilityCondition() {
        let eligible = AdaptiveAppLayoutPolicy(
            horizontalSizeClass: .regular,
            containerWidth: AdaptiveAppLayoutPolicy.minimumCompanionContainerWidth,
            isAuthenticated: true,
            selectedTab: .timeline,
            isNotificationsCompanionRequested: true
        )

        #expect(eligible.canOfferNotificationsCompanion)
        #expect(eligible.shouldPresentNotificationsCompanion)

        #expect(!policy(from: eligible, horizontalSizeClass: .compact).canOfferNotificationsCompanion)
        #expect(!policy(from: eligible, containerWidth: 999).canOfferNotificationsCompanion)
        #expect(!policy(from: eligible, isAuthenticated: false).canOfferNotificationsCompanion)
        #expect(!policy(from: eligible, isNotificationsCompanionRequested: false)
            .shouldPresentNotificationsCompanion)
        #expect(!policy(from: eligible, selectedTab: .notifications)
            .shouldPresentNotificationsCompanion)
    }

    private func policy(
        from policy: AdaptiveAppLayoutPolicy,
        horizontalSizeClass: UserInterfaceSizeClass? = nil,
        containerWidth: CGFloat? = nil,
        isAuthenticated: Bool? = nil,
        selectedTab: AppTab? = nil,
        isNotificationsCompanionRequested: Bool? = nil
    ) -> AdaptiveAppLayoutPolicy {
        AdaptiveAppLayoutPolicy(
            horizontalSizeClass: horizontalSizeClass ?? policy.horizontalSizeClass,
            containerWidth: containerWidth ?? policy.containerWidth,
            isAuthenticated: isAuthenticated ?? policy.isAuthenticated,
            selectedTab: selectedTab ?? policy.selectedTab,
            isNotificationsCompanionRequested: isNotificationsCompanionRequested
                ?? policy.isNotificationsCompanionRequested
        )
    }
}
