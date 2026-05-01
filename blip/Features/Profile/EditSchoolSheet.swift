import SwiftUI

/// Modal for setting (or clearing) the signed-in user's school string.
/// Reads/writes solely through `UserRepository` — no Firestore here.
struct EditSchoolSheet: View {
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
    private static let maxLength: Int = 40

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColor.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: Self.stackSpacing) {
                    BlipTextField(
                        label: "school",
                        placeholder: "your school",
                        text: $input,
                        isFocused: $isFieldFocused,
                        submitLabel: .done,
                        onSubmit: { Task { await save() } }
                    )

                    Text(hint)
                        .font(BlipTypography.caption)
                        .foregroundStyle(BlipColor.textTertiary)

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
            input = users.profile?.school ?? ""
            isFieldFocused = true
        }
        .onChange(of: input) { _, new in
            if new.count > Self.maxLength {
                input = String(new.prefix(Self.maxLength))
            }
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
            Text("your school")
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

    // MARK: - Helpers

    private var trimmed: String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hint: String {
        let current = users.profile?.school ?? ""
        if trimmed.isEmpty && !current.isEmpty {
            return "leave empty to remove your school."
        }
        return "shown under your handle on your profile."
    }

    private var canSave: Bool {
        let current = users.profile?.school ?? ""
        return trimmed != current
    }

    // MARK: - Actions

    private func save() async {
        guard canSave else { return }
        isSaving = true
        saveError = nil
        do {
            try await users.updateSchool(trimmed.isEmpty ? nil : trimmed)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }
}

#Preview {
    EditSchoolSheet()
        .environmentObject(UserRepository())
}
