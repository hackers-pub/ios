import Foundation

enum ComposeNoteSubmissionResult: Equatable {
    case success
    case invalidInput(inputPath: String)
    case notAuthenticated
    case failed
}

enum ComposePresentationAction: Equatable {
    case none
    case dismiss
}

struct ComposePresentationCoordinator {
    var errorMessage: String?
    var showsDiscardConfirmation = false

    var isErrorPresented: Bool {
        errorMessage != nil
    }

    mutating func requestDismiss(
        isContentDirty: Bool,
        hasPhotos: Bool,
        isBusy: Bool
    ) -> ComposePresentationAction {
        guard !isBusy else { return .none }
        guard !isContentDirty, !hasPhotos else {
            showsDiscardConfirmation = true
            return .none
        }
        return .dismiss
    }

    func interactiveDismissDisabled(
        isContentDirty: Bool,
        hasPhotos: Bool,
        isBusy: Bool
    ) -> Bool {
        isContentDirty || hasPhotos || isBusy
    }

    mutating func showError(_ message: String) {
        errorMessage = message
    }

    mutating func setErrorPresented(_ isPresented: Bool) {
        if !isPresented {
            errorMessage = nil
        }
    }

    mutating func handleSubmissionResult(
        _ result: ComposeNoteSubmissionResult
    ) -> ComposePresentationAction {
        switch result {
        case .success:
            errorMessage = nil
            showsDiscardConfirmation = false
            return .dismiss
        case let .invalidInput(inputPath):
            showError(ComposeInputErrorMapper.message(for: inputPath))
        case .notAuthenticated:
            showError(NSLocalizedString("compose.error.notAuthenticated", comment: "Not authenticated error"))
        case .failed:
            showError(NSLocalizedString("compose.error.failed", comment: "Failed to create note"))
        }
        return .none
    }
}
