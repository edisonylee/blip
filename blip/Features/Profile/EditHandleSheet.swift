import SwiftUI

// MARK: - Edit handle sheet

/// Modal for claiming or editing the signed-in user's @handle.
/// Reads/writes solely through `UserRepository` — no Firestore here.
struct EditHandleSheet: View {
    @EnvironmentObject private var users: UserRepository
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var input: String = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @FocusState private var isFieldFocused: Bool

    // MARK: - Layout constants

    private static let contentPadding: CGFloat = 20
    private static let stackSpacing: CGFloat = 20
    private static let minTapTarget: CGFloat = 44

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColor.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: Self.stackSpacing) {
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
                }
                .padding(Self.contentPadding)
            }
            .toolbar { toolbarContent }
            .toolbarBackground(BlipColor.background, for: .navigationBar)
        }
        .onAppear {
            input = users.profile?.handle ?? ""
            isFieldFocused = true
        }
    }

    // MARK: - Subviews

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("cancel") { dismiss() }
                .frame(minWidth: Self.minTapTarget, minHeight: Self.minTapTarget)
                .foregroundStyle(BlipColor.textPrimary)
        }
        ToolbarItem(placement: .principal) {
            Text("your handle")
                .font(BlipTypography.body)
                .foregroundStyle(BlipColor.textPrimary)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("save") {
                Task { await save() }
            }
            .frame(minWidth: Self.minTapTarget, minHeight: Self.minTapTarget)
            .foregroundStyle(canSave ? BlipColor.textPrimary : BlipColor.textTertiary)
            .fontWeight(.semibold)
            .disabled(!canSave || isSaving)
        }
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
        let normalized = Handle.normalize(input)
        guard Handle.isValid(normalized) else { return false }
        // No-op when unchanged from current handle.
        if let current = users.profile?.handle, current == normalized { return false }
        return true
    }

    // MARK: - Actions

    private func save() async {
        guard canSave else { return }
        isSaving = true
        saveError = nil
        do {
            try await users.claimHandle(input)
            dismiss()
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
}

// MARK: - Preview

#Preview {
    EditHandleSheet()
        .environmentObject(UserRepository())
}
