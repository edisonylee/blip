import FirebaseFirestore
import SwiftUI

// MARK: - Model

struct BlipInviteRequest: Identifiable {
    let id: String            // document id (= blipId)
    let blipName: String
    let joinCode: String
    let inviterHandle: String?
    let createdAt: Date
}

// MARK: - ViewModel

@MainActor
final class RequestsViewModel: ObservableObject {
    @Published private(set) var requests: [BlipInviteRequest] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var processingIds = Set<String>()

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    var pendingCount: Int { requests.count }

    func startListening(uid: String) {
        listener?.remove()
        isLoading = true
        listener = db
            .collection("users").document(uid)
            .collection("blipInvites")
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snap, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    let docs = snap?.documents ?? []
                    self.requests = docs.compactMap { doc -> BlipInviteRequest? in
                        let d = doc.data()
                        guard let name = d["blipName"] as? String,
                              let code = d["joinCode"]  as? String
                        else { return nil }
                        return BlipInviteRequest(
                            id: doc.documentID,
                            blipName: name,
                            joinCode: code,
                            inviterHandle: d["inviterHandle"] as? String,
                            createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                        )
                    }
                    .sorted { $0.createdAt > $1.createdAt }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        requests = []
    }

    func accept(_ req: BlipInviteRequest, uid: String, repo: BlipRepository) async {
        guard !processingIds.contains(req.id) else { return }
        processingIds.insert(req.id)
        errorMessage = nil
        do {
            _ = try await repo.joinBlip(code: req.joinCode, uid: uid)
            try await deleteInvite(req, uid: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
        processingIds.remove(req.id)
    }

    func decline(_ req: BlipInviteRequest, uid: String) async {
        guard !processingIds.contains(req.id) else { return }
        processingIds.insert(req.id)
        do {
            try await deleteInvite(req, uid: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
        processingIds.remove(req.id)
    }

    private func deleteInvite(_ req: BlipInviteRequest, uid: String) async throws {
        try await db
            .collection("users").document(uid)
            .collection("blipInvites").document(req.id)
            .delete()
    }
}

// MARK: - View

struct RequestsView: View {
    /// Shared from HomeView so the badge count stays in sync.
    @ObservedObject var vm: RequestsViewModel

    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var repo: BlipRepository

    var body: some View {
        VStack(spacing: 0) {
            header

            if vm.isLoading && vm.requests.isEmpty {
                Spacer()
                ProgressView().tint(BlipColor.accent)
                Spacer()
            } else if vm.requests.isEmpty {
                emptyState
            } else {
                list
            }

            if let err = vm.errorMessage {
                Text(err)
                    .font(.blip(size: 12))
                    .foregroundStyle(BlipColor.error)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
        }
        .task {
            guard let uid = currentUid else { return }
            vm.startListening(uid: uid)
        }
        .onDisappear { vm.stopListening() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("requests")
                    .font(BlipTypography.title)
                    .foregroundStyle(BlipColor.textPrimary)
                Text(vm.requests.isEmpty ? "all clear" : "\(vm.requests.count) pending")
                    .font(.blip(size: 13))
                    .foregroundStyle(BlipColor.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    // MARK: List

    private var list: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 14) {
                ForEach(vm.requests) { req in
                    RequestCard(
                        request: req,
                        isProcessing: vm.processingIds.contains(req.id),
                        onAccept: {
                            guard let uid = currentUid else { return }
                            Task { await vm.accept(req, uid: uid, repo: repo) }
                        },
                        onDecline: {
                            guard let uid = currentUid else { return }
                            Task { await vm.decline(req, uid: uid) }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "envelope.open")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(BlipColor.textTertiary)
            VStack(spacing: 6) {
                Text("no requests")
                    .font(BlipTypography.body)
                    .foregroundStyle(BlipColor.textPrimary)
                Text("when someone invites you to a blip,\nyou'll see it here.")
                    .font(.blip(size: 13))
                    .foregroundStyle(BlipColor.textTertiary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var currentUid: String? {
        if case .signedIn(let uid) = auth.state { return uid }
        return nil
    }
}

// MARK: - Request card

private struct RequestCard: View {
    let request: BlipInviteRequest
    let isProcessing: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Info
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(BlipColor.accent.opacity(0.13))
                        .frame(width: 48, height: 48)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(BlipColor.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(request.blipName)
                        .font(.blip(size: 16, weight: .bold))
                        .foregroundStyle(BlipColor.textPrimary)
                        .lineLimit(1)
                    if let h = request.inviterHandle {
                        Text("invited by @\(h)")
                            .font(.blip(size: 12))
                            .foregroundStyle(BlipColor.textTertiary)
                    } else {
                        Text("you've been invited")
                            .font(.blip(size: 12))
                            .foregroundStyle(BlipColor.textTertiary)
                    }
                }
                Spacer()
            }

            // Buttons
            HStack(spacing: 10) {
                Button(action: onDecline) {
                    Text("decline")
                        .font(.blip(size: 14, weight: .semibold))
                        .foregroundStyle(BlipColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(BlipColor.surface,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(BlipColor.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)

                Button(action: onAccept) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(BlipColor.accentNeutral)
                        if isProcessing {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            Text("join blip")
                                .font(.blip(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
            }
        }
        .padding(16)
        .background(BlipColor.surface,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: BlipColor.accent.opacity(0.07), radius: 8, x: 0, y: 3)
    }
}
