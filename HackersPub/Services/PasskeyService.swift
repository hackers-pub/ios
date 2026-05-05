import AuthenticationServices
import Foundation
import UIKit
@_spi(Internal) import ApolloAPI

enum PasskeyServiceError: LocalizedError {
    case invalidOptions
    case invalidChallenge
    case invalidUserID
    case unsupportedCredential
    case authorizationFailed

    var errorDescription: String? {
        switch self {
        case .invalidOptions:
            return NSLocalizedString("passkey.error.invalidOptions", comment: "Invalid passkey options error")
        case .invalidChallenge:
            return NSLocalizedString("passkey.error.invalidChallenge", comment: "Invalid passkey challenge error")
        case .invalidUserID:
            return NSLocalizedString("passkey.error.invalidUserID", comment: "Invalid passkey user ID error")
        case .unsupportedCredential:
            return NSLocalizedString("passkey.error.unsupportedCredential", comment: "Unsupported passkey credential error")
        case .authorizationFailed:
            return NSLocalizedString("passkey.error.authorizationFailed", comment: "Passkey authorization failed error")
        }
    }
}

struct PasskeyCredentialDescriptor {
    let id: Data

    init?(json: ApolloAPI.JSONObject) {
        guard let idString = json["id"] as? String,
              let id = Data(base64URLEncoded: idString)
        else {
            return nil
        }
        self.id = id
    }
}

struct PasskeyAuthenticationOptions {
    let challenge: Data
    let relyingPartyID: String
    let allowedCredentials: [PasskeyCredentialDescriptor]

    init(json: HackersPub.JSON) throws {
        guard let object = json.jsonObject else {
            throw PasskeyServiceError.invalidOptions
        }
        guard let challengeString = object["challenge"] as? String,
              let challenge = Data(base64URLEncoded: challengeString)
        else {
            throw PasskeyServiceError.invalidChallenge
        }

        let relyingPartyID = (object["rpId"] as? String) ?? "hackers.pub"
        let credentials = (object["allowCredentials"] as? [ApolloAPI.JSONValue])?
            .compactMap { $0 as? ApolloAPI.JSONObject }
            .compactMap(PasskeyCredentialDescriptor.init(json:)) ?? []

        self.challenge = challenge
        self.relyingPartyID = relyingPartyID
        self.allowedCredentials = credentials
    }
}

struct PasskeyRegistrationOptions {
    let challenge: Data
    let relyingPartyID: String
    let name: String
    let userID: Data
    let excludedCredentials: [PasskeyCredentialDescriptor]

    init(json: HackersPub.JSON) throws {
        guard let object = json.jsonObject else {
            throw PasskeyServiceError.invalidOptions
        }
        guard let challengeString = object["challenge"] as? String,
              let challenge = Data(base64URLEncoded: challengeString)
        else {
            throw PasskeyServiceError.invalidChallenge
        }
        guard let user = object["user"] as? ApolloAPI.JSONObject,
              let userIDString = user["id"] as? String,
              let userID = Data(base64URLEncoded: userIDString)
        else {
            throw PasskeyServiceError.invalidUserID
        }

        let relyingParty = object["rp"] as? ApolloAPI.JSONObject
        let relyingPartyID = (relyingParty?["id"] as? String) ?? "hackers.pub"
        let name = (user["name"] as? String) ?? (user["displayName"] as? String) ?? "Hackers' Pub"
        let credentials = (object["excludeCredentials"] as? [ApolloAPI.JSONValue])?
            .compactMap { $0 as? ApolloAPI.JSONObject }
            .compactMap(PasskeyCredentialDescriptor.init(json:)) ?? []

        self.challenge = challenge
        self.relyingPartyID = relyingPartyID
        self.name = name
        self.userID = userID
        self.excludedCredentials = credentials
    }
}

@MainActor
final class PasskeyService: NSObject {
    static let shared = PasskeyService()

    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    private override init() {}

    func authenticate(options: PasskeyAuthenticationOptions) async throws -> HackersPub.JSON {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: options.relyingPartyID)
        let request = provider.createCredentialAssertionRequest(challenge: options.challenge)
        request.userVerificationPreference = .preferred
        request.allowedCredentials = options.allowedCredentials.map {
            ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0.id)
        }

        let authorization = try await perform(request)
        guard let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion else {
            throw PasskeyServiceError.unsupportedCredential
        }

        let response: ApolloAPI.JSONEncodableDictionary = [
            "authenticatorData": credential.rawAuthenticatorData.base64URLEncodedString(),
            "clientDataJSON": credential.rawClientDataJSON.base64URLEncodedString(),
            "signature": credential.signature.base64URLEncodedString(),
            "userHandle": credential.userID.base64URLEncodedString()
        ]
        let value: ApolloAPI.JSONEncodableDictionary = [
            "id": credential.credentialID.base64URLEncodedString(),
            "rawId": credential.credentialID.base64URLEncodedString(),
            "type": "public-key",
            "response": response,
            "authenticatorAttachment": "platform"
        ]
        return HackersPub.JSON(encodableDictionary: value)
    }

    func register(options: PasskeyRegistrationOptions) async throws -> HackersPub.JSON {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: options.relyingPartyID)
        let request = provider.createCredentialRegistrationRequest(
            challenge: options.challenge,
            name: options.name,
            userID: options.userID
        )
        request.userVerificationPreference = .preferred
        request.excludedCredentials = options.excludedCredentials.map {
            ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0.id)
        }

        let authorization = try await perform(request)
        guard let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration,
              let attestationObject = credential.rawAttestationObject
        else {
            throw PasskeyServiceError.unsupportedCredential
        }

        let response: ApolloAPI.JSONEncodableDictionary = [
            "clientDataJSON": credential.rawClientDataJSON.base64URLEncodedString(),
            "attestationObject": attestationObject.base64URLEncodedString()
        ]
        let value: ApolloAPI.JSONEncodableDictionary = [
            "id": credential.credentialID.base64URLEncodedString(),
            "rawId": credential.credentialID.base64URLEncodedString(),
            "type": "public-key",
            "response": response,
            "authenticatorAttachment": "platform"
        ]
        return HackersPub.JSON(encodableDictionary: value)
    }

    private func perform(_ request: ASAuthorizationRequest) async throws -> ASAuthorization {
        guard continuation == nil else {
            throw PasskeyServiceError.authorizationFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
}

extension PasskeyService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller _: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            continuation?.resume(returning: authorization)
            continuation = nil
        }
    }

    nonisolated func authorizationController(controller _: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

extension PasskeyService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
        if Thread.isMainThread {
            return Self.currentPresentationAnchor()
        }
        return DispatchQueue.main.sync {
            Self.currentPresentationAnchor()
        }
    }

    nonisolated private static func currentPresentationAnchor() -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

private extension Data {
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = base64.count % 4
        if padding > 0 {
            base64.append(String(repeating: "=", count: 4 - padding))
        }
        self.init(base64Encoded: base64)
    }

    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
