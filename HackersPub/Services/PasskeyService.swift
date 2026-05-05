import AuthenticationServices
import Foundation
import UIKit
import ApolloAPI

enum PasskeyServiceError: LocalizedError {
    case invalidOptions
    case invalidChallenge
    case invalidUserID
    case unsupportedCredential
    case authorizationUnavailable
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
        case .authorizationUnavailable:
            return NSLocalizedString("passkey.error.authorizationUnavailable", comment: "Passkey authorization unavailable error")
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
    let userVerificationPreference: ASAuthorizationPublicKeyCredentialUserVerificationPreference
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

        guard let relyingPartyID = object["rpId"] as? String else {
            throw PasskeyServiceError.invalidOptions
        }
        let userVerificationPreference = Self.userVerificationPreference(from: object["userVerification"])
        let credentials = (object["allowCredentials"] as? [ApolloAPI.JSONValue])?
            .compactMap { $0 as? ApolloAPI.JSONObject }
            .compactMap(PasskeyCredentialDescriptor.init(json:)) ?? []

        self.challenge = challenge
        self.relyingPartyID = relyingPartyID
        self.userVerificationPreference = userVerificationPreference
        self.allowedCredentials = credentials
    }

    private static func userVerificationPreference(
        from value: ApolloAPI.JSONValue?
    ) -> ASAuthorizationPublicKeyCredentialUserVerificationPreference {
        switch value as? String {
        case "required":
            return .required
        case "discouraged":
            return .discouraged
        default:
            return .preferred
        }
    }
}

struct PasskeyRegistrationOptions {
    let challenge: Data
    let relyingPartyID: String
    let name: String
    let userID: Data
    let userVerificationPreference: ASAuthorizationPublicKeyCredentialUserVerificationPreference
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

        guard let relyingParty = object["rp"] as? ApolloAPI.JSONObject,
              let relyingPartyID = relyingParty["id"] as? String
        else {
            throw PasskeyServiceError.invalidOptions
        }
        let name = (user["name"] as? String) ?? (user["displayName"] as? String) ?? "Hackers' Pub"
        let authenticatorSelection = object["authenticatorSelection"] as? ApolloAPI.JSONObject
        let userVerificationPreference = Self.userVerificationPreference(
            from: authenticatorSelection?["userVerification"]
        )
        let credentials = (object["excludeCredentials"] as? [ApolloAPI.JSONValue])?
            .compactMap { $0 as? ApolloAPI.JSONObject }
            .compactMap(PasskeyCredentialDescriptor.init(json:)) ?? []

        self.challenge = challenge
        self.relyingPartyID = relyingPartyID
        self.name = name
        self.userID = userID
        self.userVerificationPreference = userVerificationPreference
        self.excludedCredentials = credentials
    }

    private static func userVerificationPreference(
        from value: ApolloAPI.JSONValue?
    ) -> ASAuthorizationPublicKeyCredentialUserVerificationPreference {
        switch value as? String {
        case "required":
            return .required
        case "discouraged":
            return .discouraged
        default:
            return .preferred
        }
    }
}

@MainActor
final class PasskeyService: NSObject {
    static let shared = PasskeyService()

    private var continuation: CheckedContinuation<ASAuthorization, Error>?
    private var authorizationController: ASAuthorizationController?
    private var presentationAnchor: ASPresentationAnchor?

    private override init() {}

    func authenticate(options: PasskeyAuthenticationOptions) async throws -> HackersPub.JSON {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: options.relyingPartyID)
        let request = provider.createCredentialAssertionRequest(challenge: options.challenge)
        request.userVerificationPreference = options.userVerificationPreference
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
        request.userVerificationPreference = options.userVerificationPreference
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
        guard let presentationAnchor = Self.currentPresentationAnchor() else {
            throw PasskeyServiceError.authorizationFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.presentationAnchor = presentationAnchor
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.authorizationController = controller
            controller.performRequests()
        }
    }

    private static func currentPresentationAnchor() -> ASPresentationAnchor? {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        if let keyWindow = windowScenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return keyWindow
        }
        return windowScenes.first.map(ASPresentationAnchor.init(windowScene:))
    }
}

extension PasskeyService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller _: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            continuation?.resume(returning: authorization)
            continuation = nil
            authorizationController = nil
            presentationAnchor = nil
        }
    }

    nonisolated func authorizationController(controller _: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            let serviceError: PasskeyServiceError
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .failed {
                serviceError = .authorizationUnavailable
            } else {
                serviceError = .authorizationFailed
            }
            continuation?.resume(throwing: serviceError)
            continuation = nil
            authorizationController = nil
            presentationAnchor = nil
        }
    }
}

extension PasskeyService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchor ?? Self.currentPresentationAnchor()!
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
