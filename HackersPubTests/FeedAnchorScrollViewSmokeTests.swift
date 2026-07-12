@testable import HackersPub
import Testing

struct FeedAnchorScrollViewSmokeTests {
    @Test("SOC-13: a command-free mounted adapter settles without issuing scroll work")
    @MainActor
    func mountedAdapterSettlesWithoutCommands() async throws {
        let fixture = MountedFeedAnchorFixture(commandFrameScheduler: nil)
        defer { fixture.dismantle() }

        _ = try await fixture.waitForScrollView()
        #expect(fixture.model.observedCommands.isEmpty)
    }
}
