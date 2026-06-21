import FirebaseFirestore
import PhotosUI
import SwiftUI

/// Combined "edit profile" sheet — profile photo picker + handle editor in one place.
/// Replaces the old split between the PhotosPicker in ProfileView and EditHandleSheet.
struct EditProfileSheet: View {

    // MARK: - Dependencies

    @EnvironmentObject private var users: UserRepository
    @Environment(\.dismiss) private var dismiss

    let uid: String

    // MARK: - Photo state

    @State private var pickerItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var photoError: String?

    // MARK: - Handle state

    @State private var handleInput = ""
    @State private var availability: Availability = .idle
    @State private var checkTask: Task<Void, Never>?
    @State private var isSaving = false
    @State private var saveError: String?
    @FocusState private var isHandleFocused: Bool

    private let db = Firestore.firestore()

    enum Availability: Equatable {
        case idle, checking, available, taken
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColor.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {

                        // ── Photo section ─────────────────────────────────
                        VStack(spacing: 8) {
                            PhotosPicker(selection: $pickerItem, matching: .images,
                                         photoLibrary: .shared()) {
                                ZStack {
                                    ProfileAvatarView(
                                        photoURL: users.profile?.photoURL,
                                        initials: avatarInitials,
                                        size: 96,
                                        isEditable: true
                                        // camera.fill badge (default) — correct for this sheet
                                    )
                                    if isUploadingPhoto {
                                        Circle()
                                            .fill(Color.black.opacity(0.45))
                                            .frame(width: 96, height: 96)
                                        ProgressView().tint(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(isUploadingPhoto)

                            Text("tap to change photo")
                                .font(.blip(size: 12))
                                .foregroundStyle(BlipColor.textTertiary)
                        }
                        .frame(maxWidth: .infinity)

                        // ── Handle field ──────────────────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            Text("handle")
                                .font(.blip(size: 12, weight: .semibold))
                                .foregroundStyle(BlipColor.textTertiary)
                                .padding(.horizontal, 4)

                            HStack(spacing: 10) {
                                Text("@")
                                    .font(.blip(size: 18, weight: .semibold))
                                    .foregroundStyle(BlipColor.textTertiary)

                                TextField("yourhandle", text: $handleInput)
                                    .font(.blip(size: 18, weight: .semibold))
                                    .foregroundStyle(BlipColor.textPrimary)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .submitLabel(.done)
                                    .focused($isHandleFocused)
                                    .onChange(of: handleInput) { _, _ in scheduleCheck() }
                                    .onSubmit { Task { await saveHandle() } }

                                availabilityIcon
                            }
                            .padding(14)
                            .background(BlipColor.surface,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(borderColor, lineWidth: 1.5)
                            )
                            .animation(.spring(response: 0.28), value: availability)

                            availabilityCaption
                                .padding(.horizontal, 4)
                        }
                        .padding(.horizontal, 20)

                        // ── Errors ────────────────────────────────────────
                        if let err = photoError ?? saveError {
                            Text(err)
                                .font(.blip(size: 12))
                                .foregroundStyle(BlipColor.error)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 28)
                    .padding(.bottom, 48)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                        .foregroundStyle(BlipColor.textSecondary)
                }
                ToolbarItem(placement: .principal) {
                    Text("edit profile")
                        .font(BlipTypography.body)
                        .foregroundStyle(BlipColor.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSaving {
                        ProgressView().tint(BlipColor.accentNeutral)
                    } else {
                        Button("save") { Task { await saveHandle() } }
                            .font(.blip(size: 16, weight: .semibold))
                            .foregroundStyle(canSave ? BlipColor.accentNeutral : BlipColor.textTertiary)
                            .disabled(!canSave)
                    }
                }
            }
            .toolbarBackground(BlipColor.background, for: .navigationBar)
        }
        .onAppear {
            handleInput = users.profile?.handle ?? ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isHandleFocused = true
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await uploadPhoto(item) }
        }
    }

    // MARK: - Availability UI

    @ViewBuilder
    private var availabilityIcon: some View {
        switch availability {
        case .idle: EmptyView()
        case .checking:
            ProgressView().scaleEffect(0.75).tint(BlipColor.textTertiary)
                .frame(width: 20, height: 20)
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(red: 0.2, green: 0.78, blue: 0.45))
                .font(.system(size: 18))
                .transition(.scale.combined(with: .opacity))
        case .taken:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(BlipColor.error)
                .font(.system(size: 18))
                .transition(.scale.combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var availabilityCaption: some View {
        switch availability {
        case .idle:
            Text("3–15 chars · lowercase · must start with a letter")
                .font(.blip(size: 11))
                .foregroundStyle(BlipColor.textTertiary)
        case .checking:
            Text("checking…")
                .font(.blip(size: 11))
                .foregroundStyle(BlipColor.textTertiary)
        case .available:
            Label("available", systemImage: "checkmark")
                .font(.blip(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 0.2, green: 0.78, blue: 0.45))
        case .taken:
            Label("already taken", systemImage: "xmark")
                .font(.blip(size: 11, weight: .semibold))
                .foregroundStyle(BlipColor.error)
        }
    }

    private var borderColor: Color {
        switch availability {
        case .available: return Color(red: 0.2, green: 0.78, blue: 0.45).opacity(0.55)
        case .taken:     return BlipColor.error.opacity(0.55)
        default:         return BlipColor.border
        }
    }

    // MARK: - Computed

    private var avatarInitials: String {
        guard let h = users.profile?.handle, !h.isEmpty else { return "?" }
        return QRCodeCard.initials(from: h)
    }

    private var canSave: Bool {
        let n = Handle.normalize(handleInput)
        guard Handle.isValid(n) else { return false }
        if let cur = users.profile?.handle, cur == n { return false }
        return availability == .available
    }

    // MARK: - Handle availability check

    private func scheduleCheck() {
        checkTask?.cancel()
        let n = Handle.normalize(handleInput)
        if let cur = users.profile?.handle, cur == n {
            availability = .available; return
        }
        guard Handle.isValid(n) else { availability = .idle; return }
        availability = .checking
        checkTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            let doc = try? await db.collection("usernames").document(n).getDocument()
            guard !Task.isCancelled else { return }
            let existingUid = doc?.data()?["uid"] as? String
            let taken = doc?.exists == true && existingUid != users.profile?.id
            await MainActor.run { self.availability = taken ? .taken : .available }
        }
    }

    private func saveHandle() async {
        guard canSave else { return }
        isSaving = true; saveError = nil
        do {
            try await users.claimHandle(handleInput)
            dismiss()
        } catch HandleError.alreadyTaken {
            saveError = "handle was just taken — try another."
            availability = .taken
        } catch HandleError.invalidFormat {
            saveError = "3–15 chars, lowercase, must start with a letter."
        } catch HandleError.notSignedIn {
            saveError = "you need to be signed in."
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }

    // MARK: - Photo upload

    private func uploadPhoto(_ item: PhotosPickerItem) async {
        isUploadingPhoto = true; photoError = nil
        defer { isUploadingPhoto = false; pickerItem = nil }
        do {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                photoError = "couldn't load the selected photo."
                return
            }
            let url = try await ProfilePhotoUploader().upload(image, uid: uid)
            try await users.updatePhotoURL(url)
        } catch {
            photoError = "photo upload failed — please try again."
        }
    }
}
