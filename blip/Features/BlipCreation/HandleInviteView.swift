import SwiftUI

/// Sub-view inside InviteSheet's "By Handle" tab.
/// User types a handle → availability-style lookup shows their name →
/// confirm button sends the invite via BlipInviteService.
struct HandleInviteView: View {
    let blip: Blip
    let currentUid: String
    let currentHandle: String?
    /// Pre-fill from a QR scan result. When non-nil the lookup fires immediately on appear.
    var prefillHandle: String? = nil

    @StateObject private var inviteService = BlipInviteService()
    @State private var input = ""
    @State private var lookupState: LookupState = .idle
    @State private var lookupTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    enum LookupState: Equatable {
        case idle, searching, found(uid: String, handle: String), notFound, error(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("handle")
                        .font(.blip(size: 12, weight: .semibold))
                        .foregroundStyle(BlipColor.textTertiary)
                        .padding(.horizontal, 4)

                    HStack(spacing: 10) {
                        Text("@")
                            .font(.blip(size: 17, weight: .semibold))
                            .foregroundStyle(BlipColor.textTertiary)

                        TextField("friendshandle", text: $input)
                            .font(.blip(size: 17, weight: .semibold))
                            .foregroundStyle(BlipColor.textPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .submitLabel(.search)
                            .focused($isFocused)
                            .onChange(of: input) { _, _ in scheduleLookup() }
                            .onSubmit { scheduleLookup() }

                        lookupIcon
                    }
                    .padding(14)
                    .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(fieldBorderColor, lineWidth: 1.5)
                    )
                    .animation(.spring(response: 0.28), value: lookupState)
                }

                // Status label
                lookupCaption

                // Confirm card (shown once user is found)
                if case .found(_, let handle) = lookupState {
                    foundCard(handle: handle)
                }

                // Error from invite send
                if let err = inviteService.errorMessage {
                    ErrorText(message: err)
                }

                // Success
                if let sent = inviteService.sentToHandle {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(red: 0.2, green: 0.78, blue: 0.45))
                        Text("invite sent to @\(sent)!")
                            .font(.blip(size: 14, weight: .semibold))
                            .foregroundStyle(BlipColor.textPrimary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.2, green: 0.78, blue: 0.45).opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            if let pre = prefillHandle, !pre.isEmpty {
                input = pre
                scheduleLookup()
            } else {
                isFocused = true
            }
        }
    }

    // MARK: - Found card

    private func foundCard(handle: String) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(BlipColor.surface)
                    Text(String(handle.prefix(1)).uppercased())
                        .font(.blip(size: 18, weight: .bold))
                        .foregroundStyle(BlipColor.textPrimary)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text("@\(handle)")
                        .font(.blip(size: 16, weight: .semibold))
                        .foregroundStyle(BlipColor.textPrimary)
                    Text("tap send to invite them to \(blip.name)")
                        .font(.blip(size: 12))
                        .foregroundStyle(BlipColor.textTertiary)
                }
                Spacer()
            }

            Button { sendInvite(handle: handle) } label: {
                Label("send invite", systemImage: "paperplane.fill")
            }
            .blipPrimary(isLoading: inviteService.isSending)
            .disabled(inviteService.isSending || inviteService.sentToHandle != nil)
        }
        .padding(16)
        .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }

    // MARK: - Icons / captions

    @ViewBuilder
    private var lookupIcon: some View {
        switch lookupState {
        case .idle:    EmptyView()
        case .searching:
            ProgressView().scaleEffect(0.75).tint(BlipColor.textTertiary).frame(width: 18, height: 18)
        case .found:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(red: 0.2, green: 0.78, blue: 0.45))
                .font(.system(size: 18))
        case .notFound, .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(BlipColor.error)
                .font(.system(size: 18))
        }
    }

    @ViewBuilder
    private var lookupCaption: some View {
        switch lookupState {
        case .idle:
            Text("type their @handle to find them")
                .font(.blip(size: 12))
                .foregroundStyle(BlipColor.textTertiary)
        case .searching:
            Text("searching…")
                .font(.blip(size: 12))
                .foregroundStyle(BlipColor.textTertiary)
        case .found(_, let h):
            Label("@\(h) found", systemImage: "checkmark")
                .font(.blip(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.2, green: 0.78, blue: 0.45))
        case .notFound:
            Label("no user with that handle", systemImage: "xmark")
                .font(.blip(size: 12, weight: .semibold))
                .foregroundStyle(BlipColor.error)
        case .error(let msg):
            Text(msg)
                .font(.blip(size: 12))
                .foregroundStyle(BlipColor.error)
        }
    }

    private var fieldBorderColor: Color {
        switch lookupState {
        case .found:    return Color(red: 0.2, green: 0.78, blue: 0.45).opacity(0.55)
        case .notFound, .error: return BlipColor.error.opacity(0.55)
        default:        return BlipColor.border
        }
    }

    // MARK: - Logic

    private func scheduleLookup() {
        lookupTask?.cancel()
        let n = Handle.normalize(input)
        guard Handle.isValid(n) else { lookupState = .idle; return }
        lookupState = .searching
        lookupTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            do {
                let (uid, handle) = try await inviteService.resolveHandle(n)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if uid == currentUid {
                        lookupState = .error("that's your own handle!")
                    } else {
                        lookupState = .found(uid: uid, handle: handle)
                    }
                }
            } catch InviteError.handleNotFound {
                guard !Task.isCancelled else { return }
                await MainActor.run { lookupState = .notFound }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run { lookupState = .error(error.localizedDescription) }
            }
        }
    }

    private func sendInvite(handle: String) {
        Task {
            do {
                try await inviteService.sendInvite(
                    handle: handle,
                    blip: blip,
                    inviterUid: currentUid,
                    inviterHandle: currentHandle
                )
            } catch {
                inviteService.errorMessage = error.localizedDescription
            }
        }
    }
}
