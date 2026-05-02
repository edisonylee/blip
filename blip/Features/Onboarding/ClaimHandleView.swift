import SwiftUI

/// Mandatory handle-claim screen surfaced between sign-in and Home.
///
/// `RootView` routes here whenever `auth.state == .signedIn` AND the user doc's
/// `handle` is nil/empty. There's no skip/cancel — friends search, profile
/// lookups, and the planned likes leaderboard all rely on `@handle` being
/// populated, so a nil handle leaves the user invisible to the social layer.
///
/// Reuses [Handle.normalize] / [Handle.isValid] / [UserRepository.claimHandle]
/// from `EditHandleSheet`. Once `claimHandle` succeeds the listener-driven
/// `users.profile.handle` flips non-nil and `RootView` re-routes to Home
/// automatically — no explicit dismiss call here.
struct ClaimHandleView: View {
    @EnvironmentObject private var users: UserRepository

    @State private var input: String = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Layout.stackSpacing) {
                header
                BlipTextField(
                    label: "handle",
                    placeholder: "yourhandle",
                    text: $input,
                    isFocused: $isFieldFocused,
                    submitLabel: .done,
                    onSubmit: { Task { await save() } }
                )

                validationLabel

                if let saveError {
                    Text(saveError)
                        .font(BlipTypography.caption)
                        .foregroundStyle(BlipColor.error)
                }

                Spacer()

                Button("claim and continue") {
                    Task { await save() }
                }
                .blipPrimary(isLoading: isSaving)
                .disabled(!canSave || isSaving)
                .opacity(canSave ? 1 : 0.4)
            }
            .padding(.horizontal, Layout.contentPadding)
            .padding(.top, Layout.topPadding)
            .padding(.bottom, Layout.bottomPadding)
        }
        .onAppear { isFieldFocused = true }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("pick your @handle")
                .font(.blip(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(BlipColor.textPrimary)
            Text("friends find you by this. you can change it later in profile.")
                .font(.blip(size: 14))
                .foregroundStyle(BlipColor.textTertiary)
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private var validationLabel: some View {
        let normalized = Handle.normalize(input)
        if input.isEmpty {
            Text("3–15 chars, lowercase, must start with a letter.")
                .font(BlipTypography.caption)
                .foregroundStyle(BlipColor.textTertiary)
        } else if Handle.isValid(normalized) {
            Text("looks good.")
                .font(BlipTypography.caption)
                .foregroundStyle(BlipColor.textSecondary)
        } else {
            Text("3–15 chars, lowercase, must start with a letter.")
                .font(BlipTypography.caption)
                .foregroundStyle(BlipColor.error)
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        Handle.isValid(Handle.normalize(input))
    }

    // MARK: - Actions

    private func save() async {
        guard canSave else { return }
        isSaving = true
        saveError = nil
        do {
            try await users.claimHandle(input)
            // Don't dismiss here — RootView observes `users.profile.handle`
            // and re-routes to Home as soon as the listener republishes.
        } catch HandleError.alreadyTaken {
            saveError = "that handle is taken."
        } catch HandleError.invalidFormat {
            saveError = "3–15 chars, lowercase, must start with a letter."
        } catch HandleError.notSignedIn {
            saveError = "you need to be signed in to claim a handle."
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }

    private enum Layout {
        static let stackSpacing: CGFloat = 16
        static let contentPadding: CGFloat = 24
        static let topPadding: CGFloat = 32
        static let bottomPadding: CGFloat = 32
    }
}

#Preview {
    ClaimHandleView()
        .environmentObject(UserRepository())
}
