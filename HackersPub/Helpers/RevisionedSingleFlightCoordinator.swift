import Foundation

enum RevisionedOperationResult<Value> {
    case blocked
    case current(Value)
    case stale(Value)
}

@MainActor
final class RevisionedSingleFlightCoordinator<Revision: Equatable> {
    typealias IsCurrent = @MainActor () -> Bool

    private var activeOperationID: UUID?

    func run<Value>(
        revision: Revision,
        currentRevision: @escaping @MainActor () -> Revision,
        operation: @escaping @MainActor (_ isCurrent: @escaping IsCurrent) async -> Value
    ) async -> RevisionedOperationResult<Value> {
        guard activeOperationID == nil else {
            return .blocked
        }

        let operationID = UUID()
        activeOperationID = operationID
        let isCurrent: IsCurrent = { [weak self] in
            self?.activeOperationID == operationID && currentRevision() == revision
        }
        let value = await operation(isCurrent)
        let remainsCurrent = isCurrent()
        if activeOperationID == operationID {
            activeOperationID = nil
        }
        return remainsCurrent ? .current(value) : .stale(value)
    }
}
