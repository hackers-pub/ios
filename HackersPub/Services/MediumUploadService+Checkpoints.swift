import Apollo
import Foundation

extension MediumUploadService {
    func performUpload(
        prepared: ImagePayload,
        contentLength: Int32,
        checkpointKey: MediumUploadCheckpointKey
    ) async throws -> UploadedMedium {
        let checkpoint: MediumUploadCheckpoint = if let persisted = try await loadCheckpoint(for: checkpointKey) {
            try await validatedCheckpoint(persisted)
        } else {
            try await startUpload(
                prepared: prepared,
                contentLength: contentLength,
                checkpointKey: checkpointKey
            )
        }

        return try await resumeUpload(checkpoint, prepared: prepared)
    }

    private func startUpload(
        prepared: ImagePayload,
        contentLength: Int32,
        checkpointKey: MediumUploadCheckpointKey
    ) async throws -> MediumUploadCheckpoint {
        try Task.checkCancellation()
        let startResponse = try await client.perform(
            mutation: HackersPub.StartMediumUploadMutation(
                contentType: prepared.contentType,
                contentLength: contentLength
            )
        )
        if let error = startResponse.errors?.first {
            throw MediumUploadError.server(error.localizedDescription)
        }

        let upload = startResponse.data?.startMediumUpload
        if let invalidInput = upload?.asInvalidInputError {
            throw MediumUploadError.invalidInput(invalidInput.inputPath)
        }
        if upload?.asNotAuthenticatedError != nil {
            throw MediumUploadError.notAuthenticated
        }
        guard let payload = upload?.asStartMediumUploadPayload,
              let uploadURL = URL(string: payload.uploadUrl),
              let expiresAt = parseExpiry(payload.expires)
        else {
            throw MediumUploadError.missingPayload("start")
        }

        let checkpoint = MediumUploadCheckpoint(
            key: checkpointKey,
            uploadID: payload.uploadId,
            uploadURL: uploadURL,
            method: payload.method,
            headers: payload.headers.map {
                MediumUploadCheckpointHeader(name: $0.name, value: $0.value)
            },
            expiresAt: expiresAt,
            state: .started
        )
        try validateActiveCheckpoint(checkpoint)
        try await saveCheckpoint(checkpoint)
        return checkpoint
    }

    private func resumeUpload(
        _ persistedCheckpoint: MediumUploadCheckpoint,
        prepared: ImagePayload
    ) async throws -> UploadedMedium {
        var checkpoint = persistedCheckpoint

        if checkpoint.state == .completed {
            return try await replayCompletedCheckpoint(checkpoint)
        }

        if checkpoint.state == .started || checkpoint.state == .uploading {
            checkpoint.state = .uploading
            try await saveCheckpoint(checkpoint)
            do {
                try await putUploadBody(
                    prepared.data,
                    to: checkpoint.uploadURL,
                    method: checkpoint.method,
                    headers: checkpoint.headers.map { ($0.name, $0.value) },
                    contentType: prepared.contentType,
                    beforeAttempt: { [self] in
                        try await validateActiveCheckpointBeforePUT(checkpoint)
                    }
                )
            } catch {
                if let status = MediumUploadRetryPolicy.nonReusableUploadTargetStatus(for: error) {
                    try await removeCheckpoint(for: checkpoint.key)
                    throw MediumUploadError.uploadTargetInvalid(status)
                }
                throw error
            }
            checkpoint.state = .uploaded
            try await saveCheckpoint(checkpoint)
        }

        if checkpoint.state == .uploaded {
            checkpoint.state = .finishPending
            try await saveCheckpoint(checkpoint)
        }

        guard checkpoint.state == .finishPending else {
            throw MediumUploadError.checkpointCorrupt
        }

        do {
            let medium = try await finishUpload(id: checkpoint.uploadID)
            checkpoint.state = .completed
            checkpoint.completedMedium = medium
            // If this atomic write fails, retain finishPending on disk and surface the typed
            // persistence error. Cleanup is never attempted without a durable replay result.
            try await saveCheckpoint(checkpoint)
            await cleanupCompletedCheckpoint(for: checkpoint.key)
            return medium
        } catch let error as MediumUploadError {
            if case .invalidInput = error {
                try await removeCheckpoint(for: checkpoint.key)
            }
            throw error
        }
    }

    private func validatedCheckpoint(
        _ checkpoint: MediumUploadCheckpoint
    ) async throws -> MediumUploadCheckpoint {
        do {
            if checkpoint.state == .completed {
                try validateCompletedCheckpoint(checkpoint)
            } else {
                try validateActiveCheckpoint(checkpoint)
            }
            return checkpoint
        } catch let error as MediumUploadError {
            switch error {
            case .checkpointExpired, .checkpointCorrupt:
                try await removeCheckpoint(for: checkpoint.key)
                throw error
            default:
                throw error
            }
        }
    }

    private func validateCompletedCheckpoint(_ checkpoint: MediumUploadCheckpoint) throws {
        guard checkpoint.key.version == MediumUploadCheckpointKey.currentVersion,
              let medium = checkpoint.completedMedium,
              !medium.id.isEmpty,
              !medium.url.isEmpty,
              !medium.type.isEmpty
        else {
            throw MediumUploadError.checkpointCorrupt
        }
    }

    private func validateActiveCheckpoint(_ checkpoint: MediumUploadCheckpoint) throws {
        guard checkpoint.key.version == MediumUploadCheckpointKey.currentVersion,
              !checkpoint.uploadID.isEmpty,
              checkpoint.uploadURL.scheme?.lowercased() == "https",
              checkpoint.uploadURL.host?.isEmpty == false,
              checkpoint.method == "PUT"
        else {
            throw MediumUploadError.checkpointCorrupt
        }

        guard checkpoint.expiresAt > clock.now() else {
            throw MediumUploadError.checkpointExpired
        }
    }

    private func validateActiveCheckpointBeforePUT(
        _ checkpoint: MediumUploadCheckpoint
    ) async throws {
        do {
            try validateActiveCheckpoint(checkpoint)
        } catch let error as MediumUploadError {
            if case .checkpointExpired = error {
                try await removeCheckpoint(for: checkpoint.key)
            }
            throw error
        }
    }

    private func loadCheckpoint(
        for key: MediumUploadCheckpointKey
    ) async throws -> MediumUploadCheckpoint? {
        do {
            return try await checkpointStore.loadCheckpoint(for: key)
        } catch let error as MediumUploadCheckpointStoreError {
            switch error {
            case .corruptData, .unsupportedVersion:
                throw MediumUploadError.checkpointCorrupt
            case .readFailed, .writeFailed:
                throw MediumUploadError.checkpointPersistenceFailed
            }
        } catch {
            throw MediumUploadError.checkpointPersistenceFailed
        }
    }

    private func saveCheckpoint(_ checkpoint: MediumUploadCheckpoint) async throws {
        do {
            try await checkpointStore.saveCheckpoint(checkpoint)
        } catch {
            NSLog("Medium upload stopped because its recovery checkpoint could not be persisted")
            throw MediumUploadError.checkpointPersistenceFailed
        }
    }

    private func removeCheckpoint(for key: MediumUploadCheckpointKey) async throws {
        do {
            try await checkpointStore.removeCheckpoint(for: key)
        } catch {
            NSLog("Medium upload checkpoint cleanup failed")
            throw MediumUploadError.checkpointPersistenceFailed
        }
    }

    private func replayCompletedCheckpoint(
        _ checkpoint: MediumUploadCheckpoint
    ) async throws -> UploadedMedium {
        guard let medium = checkpoint.completedMedium else {
            throw MediumUploadError.checkpointCorrupt
        }
        await cleanupCompletedCheckpoint(for: checkpoint.key)
        return medium
    }

    private func cleanupCompletedCheckpoint(for key: MediumUploadCheckpointKey) async {
        do {
            try await checkpointStore.removeCheckpoint(for: key)
        } catch {
            NSLog("Completed medium upload checkpoint cleanup will retry on the next replay")
        }
    }

    private func parseExpiry(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }

    func waitForInFlightUpload(
        key: MediumUploadCheckpointKey
    ) async throws -> UploadedMedium {
        let waiterID = UUID()
        let medium: UploadedMedium = try await withTaskCancellationHandler(operation: {
            let wasAlreadyCancelled = Task.isCancelled
            return try await withCheckedThrowingContinuation { continuation in
                registerInFlightWaiter(
                    continuation,
                    id: waiterID,
                    key: key,
                    wasAlreadyCancelled: wasAlreadyCancelled
                )
            }
        }, onCancel: {
            Task {
                await self.cancelInFlightWaiter(id: waiterID, key: key)
            }
        })
        try Task.checkCancellation()
        return medium
    }

    private func registerInFlightWaiter(
        _ continuation: UploadWaiter,
        id: UUID,
        key: MediumUploadCheckpointKey,
        wasAlreadyCancelled: Bool
    ) {
        guard var flight = inFlightUploads[key] else {
            continuation.resume(throwing: MediumUploadError.checkpointCorrupt)
            return
        }

        let cancellationArrivedFirst = flight.cancellationsBeforeRegistration.remove(id) != nil
        guard !wasAlreadyCancelled, !cancellationArrivedFirst else {
            inFlightUploads[key] = flight
            continuation.resume(throwing: CancellationError())
            return
        }

        flight.waiters[id] = continuation
        inFlightUploads[key] = flight
    }

    private func cancelInFlightWaiter(
        id: UUID,
        key: MediumUploadCheckpointKey
    ) {
        guard var flight = inFlightUploads[key] else { return }

        if let waiter = flight.waiters.removeValue(forKey: id) {
            inFlightUploads[key] = flight
            waiter.resume(throwing: CancellationError())
        } else {
            flight.cancellationsBeforeRegistration.insert(id)
            inFlightUploads[key] = flight
        }
    }

    func completeFlight(
        key: MediumUploadCheckpointKey,
        completion: FlightCompletion
    ) {
        guard let flight = inFlightUploads.removeValue(forKey: key) else { return }
        for waiter in flight.waiters.values {
            switch completion {
            case let .success(medium):
                waiter.resume(returning: medium)
            case let .failure(error):
                waiter.resume(throwing: error)
            }
        }
    }

    func inFlightWaiterCount(for key: MediumUploadCheckpointKey) -> Int {
        inFlightUploads[key]?.waiters.count ?? 0
    }
}
