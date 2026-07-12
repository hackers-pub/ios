@testable import HackersPub
import Testing

@MainActor
struct ComposePresentationCoordinatorTests {
    @Test func dirtyContentOrPhotosRequireConfirmationButCleanDraftDismisses() {
        var presentation = ComposePresentationCoordinator()

        let dirtyDecision = presentation.requestDismiss(
            isContentDirty: true,
            hasPhotos: false,
            isBusy: false
        )
        #expect(dirtyDecision == .none)
        #expect(presentation.showsDiscardConfirmation)

        presentation.showsDiscardConfirmation = false
        let photoDecision = presentation.requestDismiss(
            isContentDirty: false,
            hasPhotos: true,
            isBusy: false
        )
        #expect(photoDecision == .none)
        #expect(presentation.showsDiscardConfirmation)

        presentation.showsDiscardConfirmation = false
        let cleanDecision = presentation.requestDismiss(
            isContentDirty: false,
            hasPhotos: false,
            isBusy: false
        )
        #expect(cleanDecision == .dismiss)
    }

    @Test func busyOrDirtyDraftDisablesInteractiveDismiss() {
        let presentation = ComposePresentationCoordinator()

        #expect(presentation.interactiveDismissDisabled(
            isContentDirty: false,
            hasPhotos: false,
            isBusy: true
        ))
        #expect(presentation.interactiveDismissDisabled(
            isContentDirty: true,
            hasPhotos: false,
            isBusy: false
        ))
        #expect(!presentation.interactiveDismissDisabled(
            isContentDirty: false,
            hasPhotos: false,
            isBusy: false
        ))
    }

    @Test func alertBindingDismissalClearsCoordinatorErrorState() {
        var presentation = ComposePresentationCoordinator()
        presentation.showError("Unable to publish")

        #expect(presentation.isErrorPresented)
        presentation.setErrorPresented(false)
        #expect(presentation.errorMessage == nil)
        #expect(!presentation.isErrorPresented)
    }

    @Test func publishedSuccessDismissesWithoutDiscardConfirmation() {
        var presentation = ComposePresentationCoordinator()
        presentation.showsDiscardConfirmation = true

        let action = presentation.handleSubmissionResult(.success)

        #expect(action == .dismiss)
        #expect(!presentation.showsDiscardConfirmation)
    }
}
