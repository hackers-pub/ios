import Foundation
@testable import HackersPub
import Testing

struct ComposeViewWiringTests {
    @Test func submissionAndPhotoLoadingAcquireCoordinatorsBeforeStartingTasks() throws {
        let source = try composeViewSource()
        let toolbar = try #require(source.section(after: ".toolbar {", before: ".alert("))
        let postAction = try #require(
            toolbar.block(after: "ToolbarItem(placement: .confirmationAction)")
        )
        let postButton = try #require(postAction.block(after: "Button {"))
        #expect(postButton.contains("preparePost()"))

        let preparePost = try #require(source.block(after: "private func preparePost()"))
        let prepareSubmission = try #require(
            preparePost.range(of: "submissionCoordinator.prepareSubmission")
        )
        let submissionTask = try #require(preparePost.range(of: "Task {"))
        #expect(prepareSubmission.lowerBound < submissionTask.lowerBound)

        let selectionChange = try #require(
            source.block(after: ".onChange(of: selectedPhotoItems)")
        )
        let prepareSelection = try #require(
            selectionChange.range(of: "submissionCoordinator.preparePhotoSelection")
        )
        let photoTask = try #require(selectionChange.range(of: "Task {"))
        #expect(prepareSelection.lowerBound < photoTask.lowerBound)
    }

    @Test func dismissalAndAlertsUseThePresentationCoordinatorAtTheirBindings() throws {
        let source = try composeViewSource()
        let toolbar = try #require(source.section(after: ".toolbar {", before: ".alert("))
        let cancelAction = try #require(
            toolbar.block(after: "ToolbarItem(placement: .topBarLeading)")
        )
        let cancelButton = try #require(cancelAction.block(after: "Button {"))
        #expect(cancelButton.contains("requestDismiss()"))

        let requestDismiss = try #require(source.block(after: "private func requestDismiss()"))
        #expect(requestDismiss.contains("presentationCoordinator.requestDismiss"))

        let errorBinding = try #require(source.block(after: "private var errorAlertBinding"))
        #expect(errorBinding.contains("presentationCoordinator.isErrorPresented"))
        #expect(errorBinding.contains("presentationCoordinator.setErrorPresented"))

        let alert = try #require(source.section(after: ".alert(", before: ".overlay"))
        #expect(alert.contains("isPresented: errorAlertBinding"))
        #expect(!alert.contains("isPresented: .constant("))

        let interactiveDismiss = try #require(
            source.section(after: ".interactiveDismissDisabled(", before: "\n        }")
        )
        #expect(interactiveDismiss.contains("presentationCoordinator.interactiveDismissDisabled"))
    }

    @Test func publishSettingsArePreparedOnceAndDisabledWhileBusy() throws {
        let source = try composeViewSource()

        let settingsBody = try #require(source.section(after: "// Settings", before: ".navigationTitle"))
        #expect(settingsBody.contains("selection: visibilityPickerSelection"))
        #expect(settingsBody.contains("selection: localePickerSelection"))
        #expect(settingsBody.contains(".disabled(isBusy)"))

        let visibilityBinding = try #require(
            source.block(after: "private var visibilityPickerSelection")
        )
        #expect(visibilityBinding.contains("publishSettings.selectVisibility"))

        let localeBinding = try #require(
            source.block(after: "private var localePickerSelection")
        )
        #expect(localeBinding.contains("publishSettings.selectLanguage"))
        #expect(!localeBinding.contains("lastSelectedLocale"))

        let snapshot = try #require(
            source.block(after: "private func makePreparedNoteSubmission(")
        )
        #expect(snapshot.contains("publishSettings.prepared"))

        let post = try #require(source.block(after: "private func post("))
        #expect(post.contains("prepared.value.settings.localeToPersist"))
        #expect(!post.contains("publishSettings.localeToPersist"))
    }

    @Test func photoPickerAndLoaderUseCumulativeCapacityToken() throws {
        let source = try composeViewSource()
        let toolbar = try #require(source.section(after: ".toolbar {", before: ".alert("))

        let remainingCapacity = try #require(
            source.block(after: "private var remainingPhotoCapacity")
        )
        #expect(remainingCapacity.contains("submissionCoordinator.remainingPhotoCapacity"))
        #expect(remainingCapacity.contains("pendingPhotoAttachmentIDs"))

        let photoPicker = try #require(
            toolbar.block(after: "ToolbarItem(placement: .topBarTrailing)")
        )
        #expect(photoPicker.contains("maxSelectionCount: max(1, remainingPhotoCapacity)"))
        #expect(
            photoPicker.contains(
                ".disabled(isBusy || !isReplyContextResolved || remainingPhotoCapacity == 0)"
            )
        )

        let selectionChange = try #require(
            source.block(after: ".onChange(of: selectedPhotoItems)")
        )
        let prepareRange = try #require(
            selectionChange.range(of: "submissionCoordinator.preparePhotoSelection")
        )
        let taskRange = try #require(selectionChange.range(of: "Task {"))
        #expect(prepareRange.lowerBound < taskRange.lowerBound)
        #expect(selectionChange.contains("currentAttachmentIDs: pendingPhotoAttachmentIDs"))
        #expect(selectionChange.contains("selectedPhotoItems = []"))

        let loader = try #require(source.block(after: "private func loadPhotoAttachments("))
        #expect(loader.contains("selection.items"))
        #expect(loader.contains("selection.omittedForLimitCount"))
        #expect(loader.contains("submissionCoordinator.loadedPhotosToAppend"))
        #expect(loader.contains("for: selection.token"))
        #expect(loader.contains("pendingPhotoAttachments.append(contentsOf:"))
        #expect(loader.contains("feedback.localizedMessage"))
        #expect(loader.contains("presentationCoordinator.showError"))
    }

    @Test func photoUploadFunctionUsesTheAttachmentAdapter() throws {
        let source = try composeViewSource()
        let upload = try #require(source.block(after: "private func uploadPhotoAttachments("))

        #expect(upload.contains("where resolvedSnapshot[index].alt"))
        #expect(upload.contains("generateAltText("))
        #expect(upload.contains("ComposePhotoAttachmentUploadAdapter"))
        #expect(upload.contains("attachments: $pendingPhotoAttachments"))
        #expect(upload.contains("adapter.upload"))
        #expect(upload.contains("MediumUploadService.shared.uploadImageData"))
    }

    @Test func mutationClosureUsesTypedDispatcherAndSanitizesInvalidInputLater() throws {
        let source = try composeViewSource()
        let snapshot = try #require(
            source.block(after: "private func makePreparedNoteSubmission(")
        )
        let submit = try #require(snapshot.block(after: "let submit:"))

        #expect(snapshot.contains("guard isSupportedCreateNoteVisibility"))
        #expect(submit.contains("createNoteDispatcher.submit"))
        #expect(submit.contains("CreateNoteDispatchRequest("))
        #expect(submit.contains("case let .invalidInput(inputPath)"))
        #expect(!submit.contains("apolloClient.perform"))
        #expect(!submit.contains("presentationCoordinator.showError"))

        let post = try #require(source.block(after: "private func post("))
        #expect(post.contains("presentationCoordinator.handleSubmissionResult(result.presentationResult)"))
        #expect(post.contains("after: result.presentationResult"))
    }

    @Test func submissionSnapshotsResolvedReplySettingsAndMediaBeforeStartingTask() throws {
        let source = try composeViewSource()
        let preparePost = try #require(source.block(after: "private func preparePost()"))
        let prepareSubmission = try #require(
            preparePost.range(of: "submissionCoordinator.prepareSubmission")
        )
        let permitClosure = try #require(
            preparePost.block(after: "submissionCoordinator.prepareSubmission")
        )
        let submissionTask = try #require(preparePost.range(of: "Task {"))
        let snapshot = try #require(
            source.block(after: "private func makePreparedNoteSubmission(")
        )

        #expect(prepareSubmission.lowerBound < submissionTask.lowerBound)
        #expect(permitClosure.contains("makePreparedNoteSubmission(revision: revision)"))
        #expect(snapshot.contains("effectiveVisibility: effectiveVisibility"))
        #expect(snapshot.contains("let preparedReplyTargetID = resolvedReplyTargetID"))
        #expect(snapshot.contains("let preparedAttachments = pendingPhotoAttachments"))
        #expect(snapshot.contains("attachments: preparedAttachments"))
        #expect(snapshot.contains("guard isSupportedCreateNoteVisibility"))

        let post = try #require(source.block(after: "private func post("))
        #expect(post.contains("snapshot: preparedNote.attachments"))
        #expect(post.contains("language: preparedNote.settings.language"))
        #expect(post.contains("context: preparedNote.settings.content"))
    }

    @Test("POST-11: successful replies publish one typed event while posts refresh timelines")
    func successfulRepliesPublishTypedEventWhilePostsRefreshTimeline() throws {
        let source = try composeViewSource()
        let snapshot = try #require(
            source.block(after: "private func makePreparedNoteSubmission(")
        )
        let submit = try #require(snapshot.block(after: "let submit:"))
        let post = try #require(source.block(after: "private func post("))
        let replyEventBranch = try #require(
            post.block(after: "if let event = PostContentEvent.replyCreated(")
        )

        #expect(submit.contains("case let .created(id: noteID)"))
        #expect(submit.contains("return .created(noteID: noteID)"))
        #expect(snapshot.contains("replyTargetID: preparedReplyTargetID"))
        #expect(post.contains("case let .created(noteID) = result"))
        #expect(post.contains("replyTargetID: prepared.value.replyTargetID"))
        #expect(post.occurrences(of: "PostContentEventCenter.publish(") == 1)
        #expect(post.occurrences(of: "Notification.Name(\"RefreshTimeline\")") == 1)
        #expect(replyEventBranch.contains("PostContentEventCenter.publish(event)"))
        #expect(!replyEventBranch.contains("RefreshTimeline"))
        #expect(
            post.range(
                of: #"PostContentEventCenter\.publish\(event\)\s*\}\s*else\s*\{\s*NotificationCenter\.default\.post"#,
                options: .regularExpression
            ) != nil
        )
    }

    @Test func replyMentionSeedUsesDirtyStateOnlyForTheCurrentRequest() throws {
        let source = try composeViewSource()
        let replyLoader = try #require(source.block(after: "private func reloadReplyContext()"))
        let seed = try #require(source.block(after: "private func seedReplyMentions"))

        #expect(replyLoader.contains("seedReplyMentions(context.mentionHandles, requestID: requestID)"))
        #expect(seed.contains("dirtyState.applyReplyMentionSeed"))
        #expect(seed.contains("isCurrent: replyContextRequestID == requestID"))
    }

    private func composeViewSource() throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repositoryRoot
            .appendingPathComponent("HackersPub")
            .appendingPathComponent("Views")
            .appendingPathComponent("ComposeView.swift")

        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}

private extension String {
    func occurrences(of needle: String) -> Int {
        components(separatedBy: needle).count - 1
    }

    func section(after startMarker: String, before endMarker: String) -> String? {
        guard let start = range(of: startMarker),
              let end = range(of: endMarker, range: start.upperBound ..< endIndex)
        else {
            return nil
        }
        return String(self[start.lowerBound ..< end.lowerBound])
    }

    func block(after marker: String) -> String? {
        guard let markerRange = range(of: marker) else {
            return nil
        }

        let openingBrace: String.Index
        if marker.hasSuffix("{") {
            openingBrace = index(before: markerRange.upperBound)
        } else if let nextBrace = self[markerRange.upperBound...].firstIndex(of: "{") {
            openingBrace = nextBrace
        } else {
            return nil
        }

        var depth = 0
        var index = openingBrace
        while index < endIndex {
            switch self[index] {
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(self[openingBrace ... index])
                }
            default:
                break
            }
            index = self.index(after: index)
        }
        return nil
    }
}
