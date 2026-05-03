import AuthenticationServices
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var showPhoneAuth = false

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Wordmark + tagline
                VStack(spacing: 12) {
                    Text("blip")
                        .font(BlipTypography.wordmark)
                        .tracking(BlipTypography.titleTracking)
                        .foregroundStyle(BlipColor.textPrimary)

                    Text("a day with your people,\nstitched together.")
                        .font(BlipTypography.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(BlipColor.textSecondary)
                        .lineSpacing(4)
                }

                Spacer()

                // Auth options
                VStack(spacing: 12) {
                    // Sign in with Apple — native button with clear overlay
                    SignInWithAppleButton(onRequest: { _ in }, onCompletion: { _ in })
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 52)
                        .clipShape(Capsule())
                        .allowsHitTesting(false)
                        .overlay(
                            Button { Task { await auth.signInWithApple() } } label: { Color.clear }
                        )

                    Button {
                        showPhoneAuth = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "phone.fill")
                            Text("continue with phone")
                        }
                    }
                    .blipSecondary()

                    Button("browse without an account") {
                        Task { await auth.signInAnonymously() }
                    }
                    .blipGhost()
                    .padding(.top, 4)
                }
                .padding(.horizontal, 28)

                ErrorText(message: auth.lastError)
                    .padding(.top, 8)

                Spacer().frame(height: 40)
            }
        }
        .sheet(isPresented: $showPhoneAuth) {
            PhoneAuthView().environmentObject(auth)
        }
    }
}

#Preview {
    OnboardingView().environmentObject(AuthService())
}
