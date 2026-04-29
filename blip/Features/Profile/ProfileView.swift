import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var users: UserRepository
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var showQuietHours = false

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("settings")
                    .font(BlipTypography.title)
                    .foregroundStyle(BlipColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // Theme
                VStack(alignment: .leading, spacing: 10) {
                    Text("appearance")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BlipColor.textTertiary)
                        .padding(.horizontal, 4)

                    ThemePicker(selection: $theme.preference)
                }
                .padding(.horizontal, 20)

                // Other settings
                VStack(spacing: 0) {
                    Button {
                        showQuietHours = true
                    } label: {
                        SettingsRow(
                            title: "quiet hours",
                            value: quietHoursLabel,
                            tint: BlipColor.textPrimary
                        )
                    }

                    Divider().background(BlipColor.surfaceElevated)

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
        .sheet(isPresented: $showQuietHours) {
            QuietHoursSheet(
                start: users.profile?.quietHoursStart ?? 23,
                end: users.profile?.quietHoursEnd ?? 7
            )
        }
    }

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
        .contentShape(Rectangle())
    }
}

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
                            .foregroundStyle(.red)
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
                    .foregroundStyle(BlipColor.accent)
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

func formatHour(_ h: Int) -> String {
    let normalized = ((h % 24) + 24) % 24
    let hour12 = normalized % 12 == 0 ? 12 : normalized % 12
    let suffix = normalized < 12 ? "am" : "pm"
    return "\(hour12)\(suffix)"
}

// MARK: - Theme Picker

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
                            .font(.system(size: 16))
                        Text(option.label)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(selection == option ? .black : BlipColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selection == option ? BlipColor.accent : BlipColor.surface,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthService())
        .environmentObject(UserRepository())
        .environmentObject(ThemeManager())
}
