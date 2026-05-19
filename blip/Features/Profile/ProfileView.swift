import PhotosUI
import SwiftUI

/// Profile page — the rightmost of the home pager.
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
                BlipColor.background.ignoresSafeArea()
            }
        }
    }

    private var currentUid: String? {
        if case .signedIn(let uid) = auth.state { return uid }
        return nil
    }
}

// MARK: - Content (owns ViewModels + sheet plumbing)

private struct ProfileContent: View {

    @EnvironmentObject private var users: UserRepository

    @StateObject private var vm: ProfileViewModel
    @StateObject private var rankVM: LeaderboardViewModel

    @State private var showHandleSheet = false
    @State private var showSchoolSheet = false
    @State private var showSettings = false
    @State private var showShareSheet = false
    @State private var pickerItem: PhotosPickerItem?

    private let uid: String

    private static let avatarSize: CGFloat = 80

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

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ProfileHeader(
                    username: wordmarkText,
                    onShareProfile: { showShareSheet = true },
                    onEditProfile: { showHandleSheet = true }
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: BlipSpacing.xl) {
                        profileIdentity

                        if let err = vm.pendingError {
                            Text(err)
                                .font(BlipTypography.caption)
                                .foregroundStyle(BlipColor.error)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }

                        recentClipsSection
                    }
                    .padding(BlipSpacing.lg)
                }
            }
        }
        .task { rankVM.startListening() }
        .onDisappear { rankVM.stopListening() }
        .sheet(isPresented: $showHandleSheet) { EditHandleSheet() }
        .sheet(isPresented: $showSchoolSheet) { EditSchoolSheet() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: vm.shareItems(handle: profile?.handle))
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await vm.uploadPhoto(image)
                }
                pickerItem = nil
            }
        }
    }

    // MARK: - Profile identity (avatar + name + stats)

    private var profileIdentity: some View {
        HStack(alignment: .center, spacing: BlipSpacing.xl) {
            avatarPicker

            VStack(alignment: .leading, spacing: BlipSpacing.sm) {
                Text(profile?.displayName ?? "")
                    .font(BlipTypography.cardTitle)
                    .foregroundStyle(BlipColor.textPrimary)

                HStack(spacing: BlipSpacing.xl) {
                    statColumn(value: "\(profile?.friendsCount ?? 0)", label: "blips")
                    statColumn(value: "\(profile?.totalClips ?? 0)",   label: "clips")
                }
            }

            Spacer()
        }
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(BlipTypography.body)
                .foregroundStyle(BlipColor.textPrimary)
            Text(label)
                .font(BlipTypography.caption)
                .foregroundStyle(BlipColor.textSecondary)
        }
    }

    private var avatarPicker: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            ZStack {
                ProfileAvatarView(
                    photoURL: profile?.photoURL,
                    initials: avatarInitials,
                    size: Self.avatarSize,
                    isEditable: true
                )
                if vm.isUploadingPhoto {
                    Circle()
                        .fill(BlipColor.background.opacity(0.55))
                        .frame(width: Self.avatarSize, height: Self.avatarSize)
                    ProgressView().tint(BlipColor.textPrimary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("change profile photo")
        .disabled(vm.isUploadingPhoto)
    }

    // MARK: - Recent Clips section

    private var recentClipsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent Clips")
                .font(BlipTypography.medium)
                .foregroundStyle(BlipColor.textPrimary)
                .padding(.bottom, BlipSpacing.sm)
            Divider()
                .overlay(BlipColor.border)
        }
    }

    // MARK: - Helpers

    private var profile: BlipUser? { users.profile }

    private var wordmarkText: String {
        if let h = profile?.handle, !h.isEmpty { return h }
        return "blip"
    }

    private var avatarInitials: String {
        if let h = profile?.handle, let first = h.first { return String(first).uppercased() }
        return "?"
    }
}
