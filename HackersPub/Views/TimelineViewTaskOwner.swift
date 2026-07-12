import Foundation

@MainActor
final class TimelineViewTaskOwner {
    typealias Work = @MainActor () async -> Void

    private var supervisorTask: Task<Void, Never>?
    private var activeRequest: (id: Int, task: Task<Void, Never>)?
    private var nextRequestID = 0

    func supervise(_ work: @escaping Work) async {
        supervisorTask?.cancel()

        let task = Task { @MainActor in
            guard !Task.isCancelled else { return }
            await work()
        }
        supervisorTask = task

        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    func startRequest(_ work: @escaping Work) {
        guard activeRequest == nil else { return }

        nextRequestID += 1
        let requestID = nextRequestID

        let task = Task { @MainActor [weak self] in
            guard !Task.isCancelled else { return }
            await work()
            self?.finishRequest(id: requestID)
        }
        activeRequest = (requestID, task)
    }

    func cancelAll() {
        supervisorTask?.cancel()
        activeRequest?.task.cancel()
        supervisorTask = nil
        activeRequest = nil
    }

    private func finishRequest(id: Int) {
        guard activeRequest?.id == id else { return }
        activeRequest = nil
    }
}
