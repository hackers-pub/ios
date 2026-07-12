import Foundation
import Security

enum KeychainError: Error {
    case duplicateItem
    case itemNotFound
    case invalidData
    case unexpectedStatus(OSStatus)
}

enum KeychainPersistencePolicy {
    enum SaveAction: Equatable {
        case complete
        case add
        case fail
    }

    static func saveAction(forUpdateStatus status: OSStatus) -> SaveAction {
        switch status {
        case errSecSuccess:
            return .complete
        case errSecItemNotFound:
            return .add
        default:
            return .fail
        }
    }

    static func shouldRetrySessionLoad(for status: OSStatus) -> Bool {
        status == errSecInteractionNotAllowed
    }
}

extension KeychainError {
    var isProtectedDataUnavailable: Bool {
        guard case let .unexpectedStatus(status) = self else {
            return false
        }
        return KeychainPersistencePolicy.shouldRetrySessionLoad(for: status)
    }
}

actor KeychainHelper: SessionCredentialStore {
    static let shared = KeychainHelper()

    private let service = "pub.hackers.app"

    func save(key: String, value: String) async throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let identityQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(identityQuery as CFDictionary, attributesToUpdate as CFDictionary)
        switch KeychainPersistencePolicy.saveAction(forUpdateStatus: updateStatus) {
        case .complete:
            return
        case .add:
            let addQuery = identityQuery.merging(attributesToUpdate) { _, newValue in newValue }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
        case .fail:
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    func get(key: String) async throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else {
            throw KeychainError.invalidData
        }

        return string
    }

    func delete(key: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func delete(key: String, matchingValue: String) async throws -> Bool {
        guard let expectedData = matchingValue.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        let identityQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let readStatus = SecItemCopyMatching(identityQuery as CFDictionary, &result)
        guard readStatus != errSecItemNotFound else { return false }
        guard readStatus == errSecSuccess, let storedData = result as? Data else {
            throw KeychainError.unexpectedStatus(readStatus)
        }
        guard storedData == expectedData else { return false }
        let deleteStatus = SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ] as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(deleteStatus)
        }
        return true
    }
}
