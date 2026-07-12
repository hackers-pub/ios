@testable import HackersPub
import Testing

struct NewsToolbarPolicyTests {
    @Test func guestCanOpenSettingsButCannotSeeProfileOrAdminControls() {
        #expect(NewsToolbarPolicy.showsSettings(isAuthenticated: false))
        #expect(!NewsToolbarPolicy.showsProfile(isAuthenticated: false))
        #expect(!NewsToolbarPolicy.showsAdmin(isAuthenticated: false, isModerator: false))
    }

    @Test func authenticatedModeratorKeepsAllEligibleToolbarControls() {
        #expect(NewsToolbarPolicy.showsSettings(isAuthenticated: true))
        #expect(NewsToolbarPolicy.showsProfile(isAuthenticated: true))
        #expect(NewsToolbarPolicy.showsAdmin(isAuthenticated: true, isModerator: true))
    }
}
