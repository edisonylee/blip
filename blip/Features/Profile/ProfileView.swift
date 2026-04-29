import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("settings")
                    .font(BlipTypography.wordmark)
                    .foregroundStyle(BlipColor.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                VStack(spacing: 0) {
                    Button {
                        auth.signOut()
                    } label: {
                        SettingsRow(title: "sign out", tint: BlipColor.textPrimary)
                    }

                    Divider().background(BlipColor.surfaceElevated)

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        SettingsRow(title: "delete account", tint: .red)
                    }
                    .disabled(isDeleting)
                }
                .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)

                if let deleteError {
                    Text(deleteError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                }

                Spacer()
            }

            if isDeleting {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView("deleting…")
                    .controlSize(.large)
                    .padding(24)
                    .background(BlipColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .confirmationDialog(
            "Delete your blip account?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("delete forever", role: .destructive) {
                Task { await runDelete() }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your account, all your clips, and your membership in every blip. This cannot be undone.")
        }
    }

    private func runDelete() async {
        isDeleting = true
        deleteError = nil
        do {
            try await auth.deleteAccount()
            // Auth state listener will route us out; dismiss for good measure.
            dismiss()
        } catch {
            deleteError = error.localizedDescription
        }
        isDeleting = false
    }
}

private struct SettingsRow: View {
    let title: String
    let tint: Color

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(tint)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(BlipColor.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthService())
        .preferredColorScheme(.dark)
}
