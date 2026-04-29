import SwiftUI

struct JoinBlipView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var repo: BlipRepository
    @Environment(\.dismiss) private var dismiss

    @State private var code: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var codeFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColor.background.ignoresSafeArea()
                DoodleBackground(intensity: 0.8)

                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 6) {
                        Text("got a code?")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(BlipColor.textPrimary)
                        Text("your friend sent you a blip join code")
                            .font(.system(size: 14))
                            .foregroundStyle(BlipColor.textTertiary)
                    }
                    .padding(.top, 32)
                    .padding(.horizontal, 24)

                    Spacer()

                    // Code input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("join code")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(BlipColor.textTertiary)
                            .textCase(.uppercase)
                            .tracking(0.8)

                        HStack(spacing: 10) {
                            Text("#")
                                .font(.system(size: 22, weight: .black, design: .monospaced))
                                .foregroundStyle(BlipColor.accent)
                            TextField("c9kz6il", text: $code)
                                .focused($codeFocused)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.go)
                                .onSubmit(submit)
                                .foregroundStyle(BlipColor.textPrimary)
                                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        }
                        .padding(16)
                        .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(codeFocused ? BlipColor.accent.opacity(0.5) : BlipColor.border, lineWidth: 1)
                        )
                        .animation(.easeOut(duration: 0.2), value: codeFocused)
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // Footer
                    VStack(spacing: 12) {
                        ErrorText(message: errorMessage)

                        Button("join blip") { submit() }
                            .blipPrimary(isLoading: isSubmitting)
                            .disabled(!canSubmit || isSubmitting)
                            .opacity(canSubmit ? 1 : 0.4)
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(BlipColor.textSecondary)
                    }
                }
            }
            .toolbarBackground(BlipColor.background, for: .navigationBar)
        }
        .onAppear { codeFocused = true }
    }

    private var canSubmit: Bool {
        !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard case .signedIn(let uid) = auth.state else { return }
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                _ = try await repo.joinBlip(code: code, uid: uid)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

#Preview {
    JoinBlipView()
        .environmentObject(AuthService())
        .environmentObject(BlipRepository())
}
