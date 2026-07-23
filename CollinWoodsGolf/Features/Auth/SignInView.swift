import SwiftUI

/// Email → 6-digit code sign-in. The backend matches the email against the
/// Acuity Scheduling client list, emails a one-time code, and links the app
/// account to that Acuity client (membership tier included).
struct SignInView: View {
    @Environment(SessionStore.self) private var session

    private enum Step { case email, code }

    @State private var step: Step = .email
    @State private var email = ""
    @State private var code = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            CWTheme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                CWMonogram(size: 96)
                    .padding(.bottom, 20)

                Text("Collin Woods Golf")
                    .font(CWTheme.display(30))
                    .foregroundStyle(CWTheme.charcoal)
                Text("Play the way you work")
                    .font(CWTheme.body(15))
                    .foregroundStyle(CWTheme.stone)
                    .padding(.top, 4)

                VStack(spacing: 14) {
                    if step == .email {
                        emailStep
                    } else {
                        codeStep
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(CWTheme.body(13))
                            .foregroundStyle(.red)
                    }
                }
                .padding(.top, 36)
                .padding(.horizontal, 28)

                Spacer()
                Spacer()

                Text("Sign in with the email on your Acuity booking account.\nNew student? Reach out at \(AppConfig.supportEmail).")
                    .font(CWTheme.body(12))
                    .foregroundStyle(CWTheme.stone)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
            }
        }
    }

    private var emailStep: some View {
        Group {
            TextField("Email address", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(CWTheme.creamCard)
                .clipShape(RoundedRectangle(cornerRadius: CWTheme.cornerRadius))

            Button {
                Task { await requestCode() }
            } label: {
                if isWorking {
                    ProgressView().tint(CWTheme.cream)
                } else {
                    Text("Continue")
                }
            }
            .buttonStyle(CWPrimaryButtonStyle())
            .disabled(isWorking || !email.contains("@"))
        }
    }

    private var codeStep: some View {
        Group {
            Text("We emailed a 6-digit code to \(email).")
                .font(CWTheme.body(14))
                .foregroundStyle(CWTheme.stone)

            TextField("6-digit code", text: $code)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(CWTheme.body(24, weight: .semibold))
                .padding(14)
                .background(CWTheme.creamCard)
                .clipShape(RoundedRectangle(cornerRadius: CWTheme.cornerRadius))

            Button {
                Task { await verify() }
            } label: {
                if isWorking {
                    ProgressView().tint(CWTheme.cream)
                } else {
                    Text("Sign In")
                }
            }
            .buttonStyle(CWPrimaryButtonStyle())
            .disabled(isWorking || code.count < 4)

            Button("Use a different email") {
                step = .email
                code = ""
                errorMessage = nil
            }
            .font(CWTheme.body(14, weight: .medium))
            .foregroundStyle(CWTheme.pine)
        }
    }

    private func requestCode() async {
        isWorking = true
        errorMessage = nil
        do {
            try await session.backend.requestSignInCode(email: email)
            step = .code
        } catch {
            errorMessage = "We couldn't find that email. Use the address on your Acuity account."
        }
        isWorking = false
    }

    private func verify() async {
        isWorking = true
        errorMessage = nil
        do {
            let client = try await session.backend.verifySignInCode(email: email, code: code)
            session.didSignIn(client)
        } catch {
            errorMessage = "That code didn't match. Try again."
        }
        isWorking = false
    }
}

#Preview {
    SignInView().environment(SessionStore())
}
