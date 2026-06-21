import SwiftUI

// MARK: - Notifications sheet
//
// Aggregates two live data sources:
//   • Incoming friend requests  (FriendsRepository.incomingRequests)
//   • Pending blip invites       (RequestsViewModel.requests)
//
// Each item has an accept / decline action that calls the existing service
// layer — no new backend work needed.

struct NotificationsView: View {

    // MARK: - Dependencies (passed from HomeView so no duplicate listeners)
    @ObservedObject var requestsVM: RequestsViewModel

    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var repo: BlipRepository
    @EnvironmentObject private var friendsRepo: FriendsRepository
    @EnvironmentObject private var friendsService: FriendsService
    @Environment(\.dismiss) private var dismiss

    // MARK: - Local state
    @State private var processingFriendIds = Set<String>()
    @State private var friendError: String?
    @State private var successMessage: String?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                BlipColor.backgroundGradient.ignoresSafeArea()

                if isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {

                            // ── Friend requests ─────────────────────────────
                            if !friendsRepo.incomingRequests.isEmpty {
                                notifSection(title: "friend requests", systemImage: "person.2.fill") {
                                    ForEach(friendsRepo.incomingRequests) { req in
                                        FriendRequestCard(
                                            fromUid: req.fromUid,
                                            isProcessing: processingFriendIds.contains(req.fromUid),
                                            onAccept: { handleAcceptFriend(req) },
                                            onDecline: { handleDeclineFriend(req) }
                                        )
                                    }
                                }
                            }

                            // ── Blip invites ─────────────────────────────────
                            if !requestsVM.requests.isEmpty {
                                notifSection(title: "blip invites", systemImage: "sparkles") {
                                    ForEach(requestsVM.requests) { inv in
                                        BlipInviteCard(
                                            request: inv,
                                            isProcessing: requestsVM.processingIds.contains(inv.id),
                                            onAccept: {
                                                guard let uid = currentUid else { return }
                                                Task { await requestsVM.accept(inv, uid: uid, repo: repo) }
                                            },
                                            onDecline: {
                                                guard let uid = currentUid else { return }
                                                Task { await requestsVM.decline(inv, uid: uid) }
                                            }
                                        )
                                    }
                                }
                            }

                            // ── Error / success feedback ──────────────────────
                            if let err = friendError ?? requestsVM.errorMessage {
                                Text(err)
                                    .font(.blip(size: 12))
                                    .foregroundStyle(BlipColor.error)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }

                            if let msg = successMessage {
                                Label(msg, systemImage: "checkmark.circle.fill")
                                    .font(.blip(size: 13, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.2, green: 0.78, blue: 0.45))
                                    .padding(.horizontal, 20)
                                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                    .animation(.spring(response: 0.35), value: friendsRepo.incomingRequests.count)
                    .animation(.spring(response: 0.35), value: requestsVM.requests.count)
                }
            }
            .navigationTitle("notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(BlipColor.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(BlipColor.surface, in: Circle())
                    }
                }
            }
            .toolbarBackground(BlipColor.background, for: .navigationBar)
        }
    }

    // MARK: - Section wrapper

    @ViewBuilder
    private func notifSection<Content: View>(
        title: String, systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.blip(size: 12, weight: .bold))
                .foregroundStyle(BlipColor.textTertiary)
                .textCase(.uppercase)
                .tracking(0.6)

            VStack(spacing: 10) { content() }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell.slash")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(BlipColor.textTertiary)
            VStack(spacing: 6) {
                Text("all caught up")
                    .font(BlipTypography.body)
                    .foregroundStyle(BlipColor.textPrimary)
                Text("friend requests and blip invites\nwill appear here.")
                    .font(.blip(size: 13))
                    .foregroundStyle(BlipColor.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Friend request actions

    private func handleAcceptFriend(_ req: FriendRequest) {
        processingFriendIds.insert(req.fromUid)
        friendError = nil
        Task {
            do {
                try await friendsService.acceptRequest(req)
                await MainActor.run {
                    successMessage = "you're now friends!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        successMessage = nil
                    }
                }
            } catch {
                await MainActor.run { friendError = error.localizedDescription }
            }
            await MainActor.run { processingFriendIds.remove(req.fromUid) }
        }
    }

    private func handleDeclineFriend(_ req: FriendRequest) {
        processingFriendIds.insert(req.fromUid)
        Task {
            try? await friendsService.rejectRequest(req)
            await MainActor.run { processingFriendIds.remove(req.fromUid) }
        }
    }

    // MARK: - Helpers

    private var isEmpty: Bool {
        friendsRepo.incomingRequests.isEmpty && requestsVM.requests.isEmpty
    }

    private var currentUid: String? {
        if case .signedIn(let uid) = auth.state { return uid }
        return nil
    }
}

// MARK: - Friend request card

private struct FriendRequestCard: View {
    let fromUid: String
    let isProcessing: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Avatar
            ZStack {
                Circle()
                    .fill(BlipColor.accent.opacity(0.13))
                    .frame(width: 42, height: 42)
                Text(String(fromUid.prefix(2)).uppercased())
                    .font(.blip(size: 13, weight: .bold))
                    .foregroundStyle(BlipColor.accent)
            }

            // Text — yields space to buttons
            VStack(alignment: .leading, spacing: 2) {
                Text("friend request")
                    .font(.blip(size: 14, weight: .semibold))
                    .foregroundStyle(BlipColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .layoutPriority(0)

            Spacer(minLength: 6)

            // Buttons — fixed intrinsic size, never wrap
            HStack(spacing: 6) {
                Button(action: onDecline) {
                    Text("decline")
                        .font(.blip(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(BlipColor.textSecondary)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(BlipColor.surface, in: Capsule())
                        .overlay(Capsule().stroke(BlipColor.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)

                Button(action: onAccept) {
                    if isProcessing {
                        ProgressView().tint(.white).scaleEffect(0.7)
                            .frame(width: 52, height: 32)
                    } else {
                        Text("accept")
                            .font(.blip(size: 11, weight: .bold))
                            .lineLimit(1)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                    }
                }
                .background(BlipColor.accentNeutral, in: Capsule())
                .buttonStyle(.plain)
                .disabled(isProcessing)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(14)
        .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: BlipColor.accent.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Blip invite card

private struct BlipInviteCard: View {
    let request: BlipInviteRequest
    let isProcessing: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(BlipColor.accentNeutral.opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(BlipColor.accentNeutral)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(request.blipName)
                    .font(.blip(size: 15, weight: .bold))
                    .foregroundStyle(BlipColor.textPrimary)
                    .lineLimit(1)
                if let h = request.inviterHandle {
                    Text("invited by @\(h)")
                        .font(.blip(size: 12))
                        .foregroundStyle(BlipColor.textTertiary)
                } else {
                    Text("blip group invite")
                        .font(.blip(size: 12))
                        .foregroundStyle(BlipColor.textTertiary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onDecline) {
                    Text("decline")
                        .font(.blip(size: 12, weight: .semibold))
                        .foregroundStyle(BlipColor.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(BlipColor.surface, in: Capsule())
                        .overlay(Capsule().stroke(BlipColor.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)

                Button(action: onAccept) {
                    if isProcessing {
                        ProgressView().tint(.white).scaleEffect(0.75)
                            .frame(width: 70, height: 34)
                    } else {
                        Text("join blip")
                            .font(.blip(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                    }
                }
                .background(BlipColor.accentNeutral, in: Capsule())
                .buttonStyle(.plain)
                .disabled(isProcessing)
            }
        }
        .padding(14)
        .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: BlipColor.accentNeutral.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}
