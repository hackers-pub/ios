@testable import HackersPub
import Testing

struct FeedScrollSchedulerIsolationTests {
    @Test("SOC-13: injected display-frame operations execute on the main actor")
    @MainActor
    func manualSchedulerFencesOperationToMainActor() {
        let scheduler = ManualFeedScrollCommandFrameScheduler()
        var didExecute = false

        scheduler.schedule { _ in
            MainActor.preconditionIsolated()
            didExecute = true
        }
        scheduler.advanceFrame()
        scheduler.advanceFrame()

        #expect(didExecute)
    }
}
