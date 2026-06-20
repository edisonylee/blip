import PhotosUI
import SwiftUI

// MARK: - Shell (resolves uid from auth)

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

// MARK: - Content

private struct ProfileContent: View {

    // MARK: Dependencies / VMs

    @EnvironmentObject private var users: UserRepository
    @StateObject private var vm: ProfileViewModel
    @StateObject private var rankVM: LeaderboardViewModel

    // MARK: State

    @State private var showHandleSheet = false
    @State private var showSettings = false
    @State private var showShareSheet = false
    @State private var pickerItem: PhotosPickerItem?

    private let uid: String

    // MARK: Init

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

    // MARK: Body

    var body: some View {
        ZStack {
            BlipColor.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        identitySection
                        statsStrip
                        if let handle = profile?.handle, !handle.isEmpty {
                            QRCodeCard(handle: handle, photoURL: profile?.photoURL)
                        }
                        actionRow
                        if let err = vm.pendingError {
                            Text(err)
                                .font(BlipTypography.caption)
                                .foregroundStyle(BlipColor.error)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .task { rankVM.startListening() }
        .onDisappear { rankVM.stopListening() }
        .sheet(isPresented: $showHandleSheet) { EditHandleSheet() }
        .sheet(isPresented: $showSettings)    { SettingsView() }
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

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 4) {
            Text(profile?.handle.map { "@\($0)" } ?? "profile")
                .font(.blip(size: 17, weight: .semibold))
                .foregroundStyle(BlipColor.textPrimary)
                .lineLimit(1)

            Spacer()

            Button { showShareSheet = true } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(BlipColor.textSecondary)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("share profile")

            Button { showSettings = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(BlipColor.textSecondary)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Identity (avatar + handle + metadata)

    private var identitySection: some View {
        VStack(spacing: 14) {
            // Avatar — tap to pick photo
            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                ZStack {
                    ProfileAvatarView(
                        photoURL: profile?.photoURL,
                        initials: avatarInitials,
                        size: 96,
                        isEditable: true
                    )
                    if vm.isUploadingPhoto {
                        Circle()
                            .fill(BlipColor.background.opacity(0.55))
                            .frame(width: 96, height: 96)
                        ProgressView().tint(BlipColor.textPrimary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(vm.isUploadingPhoto)

            // Handle
            Button { showHandleSheet = true } label: {
                Text(handleDisplay)
                    .font(.blip(size: 22, weight: .bold))
                    .foregroundStyle(hasHandle ? BlipColor.textPrimary : BlipColor.textTertiary)
                    .tracking(-0.3)
            }
            .buttonStyle(.plain)

            // Metadata
            VStack(spacing: 4) {
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
            Divider().frame(height: 28).background(BlipColor.border)
            statPill(value: streakValue, label: "streak")
            Divider().frame(height: 28).background(BlipColor.border)
            statPill(value: "\(profile?.friendsCount ?? 0)", label: "friends")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button("edit profile") { showHandleSheet = true }
                .blipSecondary()
            Button("share") { showShareSheet = true }
                .blipSecondary()
        }
    }

    // MARK: - Helpers

    private var profile: BlipUser? { users.profile }
    private var hasHandle: Bool { !(profile?.handle ?? "").isEmpty }

    private var avatarInitials: String {
        if let h = profile?.handle, let c = h.first { return String(c).uppercased() }
        return "?"
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
}
