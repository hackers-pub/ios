import CryptoKit
import Foundation

struct SessionInvalidationMarker: Equatable, Sendable {
    let id: UUID
    let tokenFingerprint: String?
    let isLegacy: Bool

    init(token: String?) {
        id = UUID()
        tokenFingerprint = Self.fingerprint(for: token)
        isLegacy = false
    }

    fileprivate init(id: UUID, tokenFingerprint: String?, isLegacy: Bool = false) {
        self.id = id
        self.tokenFingerprint = tokenFingerprint
        self.isLegacy = isLegacy
    }

    fileprivate static var legacy: SessionInvalidationMarker {
        SessionInvalidationMarker(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            tokenFingerprint: nil,
            isLegacy: true
        )
    }

    func matches(token: String?) -> Bool {
        !isLegacy && tokenFingerprint == Self.fingerprint(for: token)
    }

    private static func fingerprint(for token: String?) -> String? {
        guard let token else { return nil }
        return SHA256.hash(data: Data(token.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

protocol SessionCredentialStore: Sendable {
    func save(key: String, value: String) async throws
    func get(key: String) async throws -> String?
    func delete(key: String) async throws
    func delete(key: String, matchingValue: String) async throws -> Bool
}

actor SessionCredentialOperationLane {
    private var isOccupied = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func enter() async {
        guard isOccupied else {
            isOccupied = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func leave() {
        if waiters.isEmpty {
            isOccupied = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}

protocol SessionInvalidationStore: Sendable {
    func pendingMarker() async -> SessionInvalidationMarker?
    func markPending(_ marker: SessionInvalidationMarker) async
    func clearPending(_ marker: SessionInvalidationMarker) async
    func clearPending() async
}

actor UserDefaultsSessionInvalidationStore: SessionInvalidationStore {
    static let shared = UserDefaultsSessionInvalidationStore()

    private let defaults: UserDefaults
    private let markerIDKey: String
    private let markerFingerprintKey: String
    private let legacyPendingKey: String

    init(
        defaults: UserDefaults = .standard,
        markerIDKey: String = "auth.sessionInvalidationMarkerID",
        markerFingerprintKey: String = "auth.sessionInvalidationMarkerFingerprint",
        legacyPendingKey: String = "auth.sessionInvalidationPending"
    ) {
        self.defaults = defaults
        self.markerIDKey = markerIDKey
        self.markerFingerprintKey = markerFingerprintKey
        self.legacyPendingKey = legacyPendingKey
    }

    func pendingMarker() -> SessionInvalidationMarker? {
        // swiftlint:disable opening_brace
        if let markerIDString = defaults.string(forKey: markerIDKey),
           let markerID = UUID(uuidString: markerIDString)
        {
            return SessionInvalidationMarker(
                id: markerID,
                tokenFingerprint: defaults.string(forKey: markerFingerprintKey)
            )
        }
        // swiftlint:enable opening_brace
        return defaults.bool(forKey: legacyPendingKey) ? .legacy : nil
    }

    func markPending(_ marker: SessionInvalidationMarker) {
        defaults.set(marker.id.uuidString, forKey: markerIDKey)
        if let tokenFingerprint = marker.tokenFingerprint {
            defaults.set(tokenFingerprint, forKey: markerFingerprintKey)
        } else {
            defaults.removeObject(forKey: markerFingerprintKey)
        }
        defaults.removeObject(forKey: legacyPendingKey)
        _ = defaults.synchronize()
    }

    func clearPending(_ marker: SessionInvalidationMarker) {
        guard pendingMarker() == marker else { return }
        clearPending()
    }

    func clearPending() {
        defaults.removeObject(forKey: markerIDKey)
        defaults.removeObject(forKey: markerFingerprintKey)
        defaults.removeObject(forKey: legacyPendingKey)
        _ = defaults.synchronize()
    }
}
