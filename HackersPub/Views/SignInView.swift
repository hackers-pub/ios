import SwiftUI

struct SignInView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var username = ""
    @State private var verificationCode = ""
    @State private var loginToken: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var passkeySignInTaskOwner = PasskeyTaskOwner()

    private enum LoginState {
        case enterUsername
        case enterCode
    }

    @State private var loginState: LoginState = .enterUsername

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

                Text(NSLocalizedString("signIn.title", comment: "App title on sign in screen"))
                    .font(.largeTitle)
                    .fontWeight(.bold)

                if loginState == .enterUsername {
                    VStack(spacing: 16) {
                        TextField(NSLocalizedString("signIn.username", comment: "Username field placeholder"), text: $username)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .disabled(isLoading)

                        Button {
                            Task {
                                await sendSignInLink()
                            }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text(NSLocalizedString("signIn.sendLink", comment: "Send sign-in link button"))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!SignInFlowPolicy.canRequestSignInLink(username: username) || isLoading)

                        Button {
                            startPasskeySignIn()
                        } label: {
                            Label(
                                NSLocalizedString("signIn.passkey", comment: "Sign in with passkey button"),
                                systemImage: "person.badge.key"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading)
                    }
                } else {
                    VStack(spacing: 16) {
                        Text(NSLocalizedString("signIn.checkEmail", comment: "Check email instruction"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField(NSLocalizedString("signIn.verificationCode", comment: "Verification code field"), text: $verificationCode)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .disabled(isLoading)

                        Button {
                            Task {
                                await verifyCode()
                            }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text(NSLocalizedString("signIn.verify", comment: "Verify button"))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(verificationCode.isEmpty || isLoading)

                        Button(NSLocalizedString("signIn.useDifferentUsername", comment: "Use different username button")) {
                            loginState = .enterUsername
                            verificationCode = ""
                            loginToken = nil
                            errorMessage = nil
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .navigationTitle(NSLocalizedString("nav.signIn", comment: "Sign in navigation title"))
            .onChange(of: username) { _, _ in
                errorMessage = nil
            }
            .onDisappear {
                cancelPasskeySignIn()
            }
        }
    }

    private func startPasskeySignIn() {
        passkeySignInTaskOwner.start {
            await signInWithPasskey()
        }
    }

    private func cancelPasskeySignIn() {
        passkeySignInTaskOwner.cancel()
    }

    private func sendSignInLink() async {
        let username = SignInFlowPolicy.trimmedUsername(username)
        guard !username.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let verifyUrl = "https://hackers.pub/sign/in/{token}?code={code}"

            let token = try await authManager.loginByUsername(
                username: username,
                verifyUrl: verifyUrl
            )

            loginToken = token
            loginState = .enterCode
        } catch let error as AuthError {
            errorMessage = error.localizedDescription
        } catch {
            #if DEBUG
                NSLog("SignIn sendSignInLink unexpected error: \(String(describing: error))")
            #endif
            errorMessage = NSLocalizedString("signIn.unexpectedError", comment: "Unexpected error message")
        }
    }

    private func verifyCode() async {
        guard case let .verify(token) = SignInFlowPolicy.verificationAction(loginToken: loginToken) else {
            recoverFromMissingVerificationSession()
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authManager.completeLoginChallenge(token: token, code: verificationCode)
            // Auth state will update automatically via @Observable
        } catch let error as AuthError {
            errorMessage = error.localizedDescription
        } catch {
            #if DEBUG
                NSLog("SignIn verifyCode unexpected error: \(String(describing: error))")
            #endif
            errorMessage = NSLocalizedString("signIn.unexpectedError", comment: "Unexpected error message")
        }
    }

    private func recoverFromMissingVerificationSession() {
        loginState = .enterUsername
        loginToken = nil
        verificationCode = ""
        errorMessage = NSLocalizedString(
            "signIn.error.missingVerificationSession",
            comment: "Missing sign-in verification session error"
        )
    }

    private func signInWithPasskey() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await authManager.signInWithPasskey()
        } catch let error as AuthError {
            errorMessage = error.localizedDescription
        } catch {
            guard !Task.isCancelled,
                  PasskeyAuthorizationErrorPolicy.shouldPresent(error)
            else { return }
            if let error = error as? PasskeyServiceError {
                errorMessage = error.localizedDescription
            } else {
                errorMessage = NSLocalizedString("signIn.unexpectedError", comment: "Unexpected error message")
            }
        }
    }
}

#Preview {
    SignInView()
        .environment(AuthManager.shared)
}
