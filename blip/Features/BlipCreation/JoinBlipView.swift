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

                VStack(alignment: .leading, spacing: 24) {
                    Text("→ join a blip")
                        .font(BlipTypography.body)
                        .foregroundStyle(BlipColor.textPrimary)

                    HStack(spacing: 4) {
                        Text("#")
                            .foregroundStyle(BlipColor.textSecondary)
                        TextField(
                            "code",
                            text: $code,
                            prompt: Text("code").foregroundStyle(BlipColor.textSecondary)
                        )
                        .focused($codeFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit(submit)
                        .foregroundStyle(BlipColor.textPrimary)
                        .font(.system(size: 18, weight: .regular, design: .monospaced))
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundStyle(BlipColor.textPrimary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("blip").font(BlipTypography.title).foregroundStyle(BlipColor.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: submit) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(canSubmit ? BlipColor.accent : BlipColor.textTertiary)
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
            .toolbarBackground(BlipColor.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
