import SwiftUI

// MARK: - Shell

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var users: UserRepository
    @EnvironmentObject private var userDirectory: FirestoreUserDirectory

    var body: some View {
        Group {
            if let uid = currentUid {
                ProfileContent(
                    uid: uid,
                    userMutator: users,
                    photoUploader: ProfilePhotoUploader(),
                    userDirectory: userDirectory
                )
            } else {
                BlipColor.backgroundGradient.ignoresSafeArea()
            }
        }
    }

    private var currentUid: String? {
        if case .signedIn(let uid) = auth.state { return uid }
        return nil
    }
}

// MARK: - Content

private struct ProfileContent: View {

    // MARK: - Dependencies

    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var users: UserRepository
    @StateObject private var vm: ProfileViewModel
    @StateObject private var rankVM: LeaderboardViewModel

    // MARK: - Sheet / navigation state

    @State private var showEditProfile    = false   // combined photo + handle sheet
    @State private var showShareSheet     = false
    @State private var showQR             = false
    @State private var showQuietHours     = false
    @State private var showPrivacyPolicy  = false
    @State private var showDeleteConfirm  = false
    @State private var isDeleting         = false
    @State private var deleteError: String?

    private let uid: String

    // MARK: - Init

    init(
        uid: String,
        userMutator: any BlipUserMutating,
        photoUploader: any ProfilePhotoUploading,
        userDirectory: any UserRanking
    ) {
        self.uid = uid
        _vm = StateObject(wrappedValue: ProfileViewModel(
            uid: uid,
            userMutator: userMutator,
            photoUploader: photoUploader
        ))
        _rankVM = StateObject(wrappedValue: LeaderboardViewModel(userDirectory: userDirectory))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            BlipColor.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // ── Avatar + handle ───────────────────────────────────
                    identitySection

                    // ── Stats strip ───────────────────────────────────────
                    statsStrip

                    // ── Account section ───────────────────────────────────
                    menuCard {
                        menuRow(
                            icon: "pencil", iconTint: BlipColor.accentNeutral,
                            title: "edit profile"
                        ) { showEditProfile = true }

                        menuDivider

                        menuRow(
                            icon: "square.and.arrow.up", iconTint: BlipColor.accentNeutral,
                            title: "share profile"
                        ) { showShareSheet = true }

                        if let handle = profile?.handle, !handle.isEmpty {
                            menuDivider
                            qrMenuRow(handle: handle)
                        }
                    }

                    // ── Preferences section ───────────────────────────────
                    menuCard {
                        menuRow(
                            icon: "moon.zzz.fill", iconTint: Color(hex: 0x6366F1),
                            title: "quiet hours",
                            trailing: quietHoursLabel
                        ) { showQuietHours = true }

                        menuDivider

                        menuRow(
                            icon: "lock.shield.fill", iconTint: Color(hex: 0x0891B2),
                            title: "privacy policy"
                        ) { showPrivacyPolicy = true }
                    }

                    // ── Danger zone ───────────────────────────────────────
                    menuCard {
                        menuRow(
                            icon: "rectangle.portrait.and.arrow.right",
                            iconTint: BlipColor.textSecondary,
                            title: "sign out",
                            textTint: BlipColor.textPrimary,
                            showChevron: false
                        ) { auth.signOut() }

                        menuDivider

                        menuRow(
                            icon: "trash.fill",
                            iconTint: BlipColor.error,
                            title: "delete account",
                            textTint: BlipColor.error,
                            showChevron: false
                        ) { showDeleteConfirm = true }
                        .disabled(isDeleting)
                    }

                    if let deleteError {
                        Text(deleteError)
                            .font(.blip(size: 12))
                            .foregroundStyle(BlipColor.error)
                            .multilineTextAlignment(.center)
                    }

                    if let err = vm.pendingError {
                        Text(err)
                            .font(.blip(size: 12))
                            .foregroundStyle(BlipColor.error)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 36)   // extra top since there's no top bar
                .padding(.bottom, 48)
            }

            // Full-screen spinner while deleting
            if isDeleting {
                BlipColor.backgroundGradient.opacity(0.7).ignoresSafeArea()
                ProgressView("deleting…")
                    .controlSize(.large)
                    .padding(28)
                    .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .task { rankVM.startListening() }
        .onDisappear { rankVM.stopListening() }
        .sheet(isPresented: $showEditProfile) { EditProfileSheet(uid: uid) }
        .sheet(isPresented: $showShareSheet)  {
            ShareSheet(activityItems: vm.shareItems(handle: profile?.handle))
        }
        // QR bottom sheet — medium detent so it rises from the bottom
        .sheet(isPresented: $showQR) {
            if let handle = profile?.handle, !handle.isEmpty {
                ProfileQRBottomSheet(
                    handle: handle,
                    photoURL: profile?.photoURL
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(BlipColor.backgroundGradient)
            }
        }
        .sheet(isPresented: $showQuietHours) {
            QuietHoursSheet(
                start: profile?.quietHoursStart ?? 23,
                end:   profile?.quietHoursEnd   ?? 7
            )
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            NavigationStack { PrivacyPolicyView() }
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
        // pickerItem removed — photo upload now lives in EditProfileSheet
    }

    // MARK: - Identity section (avatar + handle + date)

    private var identitySection: some View {
        VStack(spacing: 14) {
            // Avatar — tap to show QR code bottom sheet
            Button { showQR = true } label: {
                ProfileAvatarView(
                    photoURL: profile?.photoURL,
                    initials: avatarInitials,
                    size: 96,
                    isEditable: true,
                    badgeIcon: "qrcode"   // shows QR icon badge instead of camera
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("show my QR code")

            // Handle — tap opens edit profile sheet
            Button { showEditProfile = true } label: {
                Text(handleDisplay)
                    .font(.blip(size: 22, weight: .bold))
                    .foregroundStyle(hasHandle ? BlipColor.textPrimary : BlipColor.textTertiary)
                    .tracking(-0.3)
            }
            .buttonStyle(.plain)

            // Metadata
            VStack(spacing: 3) {
                Text(memberSinceText)
                    .font(.blip(size: 13))
                    .foregroundStyle(BlipColor.textTertiary)
                if let school = profile?.school {
                    Text(school)
                        .font(.blip(size: 13))
                        .foregroundStyle(BlipColor.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats strip

    private var statsStrip: some View {
        HStack(spacing: 0) {
            statPill(value: "\(profile?.totalClips ?? 0)", label: "clips")
            Divider().frame(height: 28)
            statPill(value: streakValue, label: "streak")
            Divider().frame(height: 28)
            statPill(value: "\(profile?.friendsCount ?? 0)", label: "friends")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.blip(size: 18, weight: .bold))
                .foregroundStyle(BlipColor.textPrimary)
            Text(label)
                .font(.blip(size: 11))
                .foregroundStyle(BlipColor.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - QR menu row (mini thumbnail on right)

    private func qrMenuRow(handle: String) -> some View {
        let initials = QRCodeCard.initials(from: handle)
        return Button { showQR = true } label: {
            HStack(spacing: 12) {
                iconBox(systemName: "qrcode", tint: Color(hex: 0x374151))
                Text("my QR code")
                    .font(.blip(size: 15, weight: .medium))
                    .foregroundStyle(BlipColor.textPrimary)
                Spacer()
                // Mini QR preview — no labels, just the code
                QRCodeImageView(
                    data: "blip://user/\(handle)",
                    centerURL: profile?.photoURL,
                    centerInitials: initials,
                    size: 38
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BlipColor.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Menu card container

    @ViewBuilder
    private func menuCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    // MARK: - Menu row

    private func menuRow(
        icon: String,
        iconTint: Color,
        title: String,
        trailing: String? = nil,
        textTint: Color = BlipColor.textPrimary,
        showChevron: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                iconBox(systemName: icon, tint: iconTint)
                Text(title)
                    .font(.blip(size: 15, weight: .medium))
                    .foregroundStyle(textTint)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.blip(size: 13))
                        .foregroundStyle(BlipColor.textTertiary)
                }
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(BlipColor.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Icon box (iOS Settings style)

    private func iconBox(systemName: String, tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.13))
                .frame(width: 32, height: 32)
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    private var menuDivider: some View {
        Divider()
            .padding(.leading, 60) // indent to align with text, past icon
    }

    // MARK: - Delete

    private func runDelete() async {
        isDeleting = true
        deleteError = nil
        do {
            try await auth.deleteAccount()
        } catch {
            deleteError = error.localizedDescription
        }
        isDeleting = false
    }

    // MARK: - Computed helpers

    private var profile: BlipUser? { users.profile }
    private var hasHandle: Bool { !(profile?.handle ?? "").isEmpty }

    private var avatarInitials: String {
        guard let h = profile?.handle, !h.isEmpty else { return "?" }
        return QRCodeCard.initials(from: h)
    }

    private var handleDisplay: String {
        if let h = profile?.handle, !h.isEmpty { return "@\(h)" }
        return "claim your handle"
    }

    private var memberSinceText: String {
        guard let d = profile?.createdAt else { return "joined recently" }
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return "on blip since \(f.string(from: d))"
    }

    private var streakValue: String {
        let n = profile?.streakCurrent ?? 0
        return n == 1 ? "1 day" : "\(n)d"
    }

    private var quietHoursLabel: String {
        let s = profile?.quietHoursStart ?? 23
        let e = profile?.quietHoursEnd   ?? 7
        return "\(formatHour(s)) – \(formatHour(e))"
    }
}

// MARK: - QR bottom sheet (compact, medium detent)

/// Compact bottom sheet presented when the user taps their avatar.
/// Shows the profile QR code with the handle and a brief instruction.
private struct ProfileQRBottomSheet: View {
    let handle: String
    let photoURL: URL?

    private var qrData: String { "blip://user/\(handle)" }
    private var initials: String { QRCodeCard.initials(from: handle) }

    var body: some View {
        VStack(spacing: 20) {
            // Handle label
            Text("@\(handle)")
                .font(.blip(size: 20, weight: .bold))
                .foregroundStyle(BlipColor.textPrimary)
                .padding(.top, 20)

            // QR code with profile photo centre
            QRCodeImageView(
                data: qrData,
                centerURL: photoURL,
                centerInitials: initials,
                size: 220
            )
            .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 5)

            Text("others scan this to add you to their blip")
                .font(.blip(size: 13))
                .foregroundStyle(BlipColor.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Hour formatter (shared with QuietHoursSheet)

func formatHour(_ h: Int) -> String {
    let n = ((h % 24) + 24) % 24
    let h12 = n % 12 == 0 ? 12 : n % 12
    return "\(h12)\(n < 12 ? "am" : "pm")"
}
