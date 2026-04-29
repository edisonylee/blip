import SwiftUI

/// Settings sheet — surfaces from the gear icon in the home header. Holds the
/// chrome that used to live on the profile page (theme, quiet hours, sign out,
/// delete). The profile page is now scoped to identity + stats; this is the
/// account / preferences box.
struct SettingsView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var users: UserRepository
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var showQuietHours = false

    // MARK: - Layout constants

    private static let horizontalPadding: CGFloat = 20
    private static let sectionSpacing: CGFloat = 24

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColor.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Self.sectionSpacing) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("appearance")
                                .font(.blip(size: 12, weight: .semibold))
                                .foregroundStyle(BlipColor.textTertiary)
                                .padding(.horizontal, 4)

                            ThemePicker(selection: $theme.preference)
                        }
                        .padding(.horizontal, Self.horizontalPadding)

                        VStack(spacing: 0) {
                            Button { showQuietHours = true } label: {
                                SettingsRow(
                                    title: "quiet hours",
                                    value: quietHoursLabel,
                                    tint: BlipColor.textPrimary
                                )
                            }

                            Divider().background(BlipColor.surfaceElevated)

                            Button { auth.signOut() } label: {
                                SettingsRow(title: "sign out", tint: BlipColor.textPrimary)
                            }

                            Divider().background(BlipColor.surfaceElevated)

                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                SettingsRow(title: "delete account", tint: BlipColor.error)
                            }
                            .disabled(isDeleting)
                        }
                        .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, Self.horizontalPadding)

                        if let deleteError {
                            Text(deleteError)
                                .font(BlipTypography.caption)
                                .foregroundStyle(BlipColor.error)
                                .padding(.horizontal, Self.horizontalPadding)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, Self.sectionSpacing)
                }

                if isDeleting {
                    BlipColor.background.opacity(0.6).ignoresSafeArea()
                    ProgressView("deleting…")
                        .controlSize(.large)
                        .padding(24)
                        .background(BlipColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("settings")
                        .font(BlipTypography.body)
                        .foregroundStyle(BlipColor.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                        .foregroundStyle(BlipColor.textPrimary)
                }
            }
            .toolbarBackground(BlipColor.background, for: .navigationBar)
        }
        .confirmationDialog(
            "delete your blip account?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("delete forever", role: .destructive) {
                Task { await runDelete() }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("this permanently removes your account, all your clips, and your membership in every blip. it can't be undone.")
        }
        .sheet(isPresented: $showQuietHours) {
            QuietHoursSheet(
                start: users.profile?.quietHoursStart ?? 23,
                end: users.profile?.quietHoursEnd ?? 7
            )
        }
    }

    // MARK: - Helpers

    private var quietHoursLabel: String {
        let start = users.profile?.quietHoursStart ?? 23
        let end = users.profile?.quietHoursEnd ?? 7
        return "\(formatHour(start)) – \(formatHour(end))"
    }

    private func runDelete() async {
        isDeleting = true
        deleteError = nil
        do {
            try await auth.deleteAccount()
            dismiss()
        } catch {
            deleteError = error.localizedDescription
        }
        isDeleting = false
    }
}

// MARK: - Settings row

private struct SettingsRow: View {
    let title: String
    var value: String? = nil
    let tint: Color

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(tint)
            Spacer()
            if let value {
                Text(value)
                    .foregroundStyle(BlipColor.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(BlipColor.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

// MARK: - Quiet hours sheet

private struct QuietHoursSheet: View {
    @EnvironmentObject private var users: UserRepository
    @Environment(\.dismiss) private var dismiss

    @State var start: Int
    @State var end: Int
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColor.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 24) {
                    Text("no notifications between these hours.")
                        .font(BlipTypography.body)
                        .foregroundStyle(BlipColor.textSecondary)

                    HStack(spacing: 16) {
                        HourPicker(label: "from", hour: $start)
                        HourPicker(label: "to", hour: $end)
                    }

                    if let saveError {
                        Text(saveError)
                            .font(.footnote)
                            .foregroundStyle(BlipColor.error)
                    }

                    Spacer()
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                        .foregroundStyle(BlipColor.textPrimary)
                }
                ToolbarItem(placement: .principal) {
                    Text("quiet hours")
                        .font(BlipTypography.body)
                        .foregroundStyle(BlipColor.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") {
                        Task { await save() }
                    }
                    .foregroundStyle(BlipColor.textPrimary)
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
            .toolbarBackground(BlipColor.background, for: .navigationBar)
        }
    }

    private func save() async {
        isSaving = true
        saveError = nil
        do {
            try await users.updateQuietHours(start: start, end: end)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Hour picker

private struct HourPicker: View {
    let label: String
    @Binding var hour: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(BlipTypography.caption)
                .foregroundStyle(BlipColor.textTertiary)
            Picker(label, selection: $hour) {
                ForEach(0..<24, id: \.self) { h in
                    Text(formatHour(h)).tag(h)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity, maxHeight: 140)
            .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private func formatHour(_ h: Int) -> String {
    let normalized = ((h % 24) + 24) % 24
    let hour12 = normalized % 12 == 0 ? 12 : normalized % 12
    let suffix = normalized < 12 ? "am" : "pm"
    return "\(hour12)\(suffix)"
}

// MARK: - Theme picker

private struct ThemePicker: View {
    @Binding var selection: ThemePreference

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ThemePreference.allCases) { option in
                Button {
                    withAnimation(.spring(duration: 0.25)) { selection = option }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: option.icon)
                            .font(.blip(size: 16))
                        Text(option.label)
                            .font(.blip(size: 11, weight: .medium))
                    }
                    .foregroundStyle(selection == option ? BlipColor.accentNeutralOn : BlipColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selection == option ? BlipColor.accentNeutral : BlipColor.surface,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
