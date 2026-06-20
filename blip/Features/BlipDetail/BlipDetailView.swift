import AVKit
import SwiftUI

/// Today's blip view. Each hour is rendered as a `MemberGrid` mirroring the
/// server-side export composition: stable seat positions per `blip.members`
/// order, missing posters fill with a black cell on past hours, and unfilled
/// member capacity surfaces "invite a friend" cells in the same grid.
struct BlipDetailView: View {
    let blip: Blip

    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var moderation: ModerationService
    @EnvironmentObject private var blipsRepo: BlipRepository
    @EnvironmentObject private var users: UserRepository
    @StateObject private var clips = ClipsRepository()
    @StateObject private var nudges = NudgeService()
    @StateObject private var profiles = UserProfilesRepository()
    @Environment(\.dismiss) private var dismiss

    @State private var showShareSheet = false
    @State private var showInviteSheet = false
    @State private var showMembers = false
    @State private var showCapture = false
    @State private var showArchive = false
    @State private var showExport = false
    @State private var captionEditingClip: BlipClip?
    @State private var selectedHourOverride: Int?
    @State private var pendingNudgeeUid: String?

    var body: some View {
        ZStack {
            BlipColor.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    scheduleStatus

                    HourSlider(
                        hours: todayHours,
                        currentHour: currentHour,
                        selectedHour: Binding(
                            get: { selectedHour },
                            set: { selectedHourOverride = $0 }
                        )
                    )

                    MemberGrid(
                        blip: blip,
                        hour: selectedHour,
                        clipsForHour: clips.clipsByHour[selectedHour] ?? [],
                        currentUid: currentUid,
                        isCurrentHour: isWindowActive && selectedHour == currentHour,
                        onRecord: { if isWindowActive { showCapture = true } },
                        onInvite: { showInviteSheet = true },
                        isAuthor: isAuthor(of:),
                        onDelete: { clip in Task { try? await clips.deleteClip(clip) } },
                        onEditCaption: { clip in captionEditingClip = clip },
                        onNudge: { uid in pendingNudgeeUid = uid },
                        initialsForUid: { uid in
                            uid == currentUid ? "me" : profiles.initials(for: uid)
                        }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 64)
            }
        }
        .task(id: blip.id) {
            clips.startListening(blip: blip)
            clips.setBlocklist(moderation.blockedUsers)
            profiles.observe(uids: blip.members)
            profiles.setBlocklist(moderation.blockedUsers)
        }
        .onChange(of: blip.members) { _, new in
            profiles.observe(uids: new)
        }
        .onReceive(moderation.$blockedUsers) { uids in
            clips.setBlocklist(uids)
            profiles.setBlocklist(uids)
        }
        .onReceive(blipsRepo.$blips) { blips in
            // Pop to Home when this blip leaves the user's list — covers
            // delete (server tears down the doc), leave (arrayRemove), and
            // being kicked (owner removes a member). Idempotent: if the view
            // is already gone, dismiss is a no-op.
            if !blips.contains(where: { $0.id == blip.id }) {
                dismiss()
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(blip.name)
                    .font(BlipTypography.body)
                    .foregroundStyle(BlipColor.textPrimary)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    // Chat — primary action, always visible
                    NavigationLink {
                        ChatView(blip: blip)
                    } label: {
                        Image(systemName: "bubble.right")
                            .foregroundStyle(BlipColor.textPrimary)
                    }
                    .accessibilityLabel("chat")

                    // Overflow — members, share, archive, export
                    Menu {
                        Button { showMembers = true } label: {
                            Label("members", systemImage: "person.2")
                        }
                        Button { showShareSheet = true } label: {
                            Label("share invite", systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        Button { showArchive = true } label: {
                            Label("archive", systemImage: "calendar")
                        }
                        Button { showExport = true } label: {
                            Label("export", systemImage: "film")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(BlipColor.textPrimary)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showArchive) {
            ArchiveView(blip: blip)
        }
        .navigationDestination(isPresented: $showExport) {
            ExportView(blip: blip)
        }
        .toolbarBackground(BlipColor.backgroundGradient, for: .navigationBar)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [inviteShareText])
        }
        .sheet(isPresented: $showInviteSheet) {
            InviteSheet(
                blip: blip,
                currentUid: currentUid ?? "",
                currentHandle: users.profile?.handle
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showMembers) {
            MembersSheet(blip: blip)
        }
        .fullScreenCover(isPresented: $showCapture) {
            NavigationStack {
                CaptureView(blip: blip, onPosted: { showCapture = false })
            }
        }
        .sheet(item: $captionEditingClip) { clip in
            EditCaptionSheet(clip: clip) { newCaption in
                try? await clips.updateCaption(clip, caption: newCaption)
            }
        }
        .confirmationDialog(
            nudgeDialogTitle,
            isPresented: nudgeDialogBinding,
            titleVisibility: .visible,
            presenting: pendingNudgeeUid
        ) { uid in
            Button("send nudge") { sendNudge(to: uid) }
            Button("cancel", role: .cancel) { pendingNudgeeUid = nil }
        } message: { _ in
            Text("one tap, one push. no repeats this hour.")
        }
    }

    private var nudgeDialogTitle: String {
        guard let uid = pendingNudgeeUid,
              let first = profiles.firstName(for: uid)
        else { return "send a nudge?" }
        return "send a nudge to \(first)?"
    }

    private var nudgeDialogBinding: Binding<Bool> {
        Binding(
            get: { pendingNudgeeUid != nil },
            set: { if !$0 { pendingNudgeeUid = nil } }
        )
    }

    private func sendNudge(to nudgeeUid: String) {
        guard let me = currentUid else { return }
        pendingNudgeeUid = nil
        Task {
            try? await nudges.sendNudge(
                blipId: blip.id,
                blipTimezone: blip.timezoneIdentifier,
                activeStartHour: blip.activeStartHour,
                activeEndHour: blip.activeEndHour,
                senderUid: me,
                nudgeeUid: nudgeeUid
            )
        }
    }

    private var inviteShareText: String {
        InviteShare.text(blipName: blip.name, joinCode: blip.joinCode, referrerUid: currentUid)
    }

    private func isAuthor(of clip: BlipClip) -> Bool {
        guard case .signedIn(let uid) = auth.state else { return false }
        return clip.uid == uid
    }

    private var currentUid: String? {
        if case .signedIn(let uid) = auth.state { return uid }
        return nil
    }

    private var currentHour: Int {
        BlipHour.currentHour(in: blip.timezoneIdentifier)
    }

    private var isWindowActive: Bool { blip.isActive() }

    private var selectedHour: Int {
        selectedHourOverride ?? currentHour
    }

    /// Slider nodes for today: every recorded hour plus the current hour,
    /// sorted in chronological order anchored to the configured group start.
    /// With no past recordings the slider degenerates to a single node (now).
    private var todayHours: [Int] {
        let recorded = Set(clips.clipsByHour.keys.filter {
            BlipHour.isActive(hour: $0, startHour: blip.activeStartHour, endHour: blip.activeEndHour)
        })
        let nodes = isWindowActive ? recorded.union([currentHour]) : recorded
        if nodes.isEmpty { return [blip.activeStartHour] }
        return nodes.sorted { lhs, rhs in
            BlipHour.sortIndex(for: lhs, startHour: blip.activeStartHour)
                < BlipHour.sortIndex(for: rhs, startHour: blip.activeStartHour)
        }
    }

    private var scheduleStatus: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isWindowActive ? BlipColor.accent : BlipColor.textTertiary)
                .frame(width: 7, height: 7)
            Text(isWindowActive ? "recording open" : "recording closed")
                .font(.blip(size: 12, weight: .semibold))
                .foregroundStyle(BlipColor.textSecondary)
            Spacer()
            Text("\(BlipHour.hourLabel(blip.activeStartHour))–\(BlipHour.hourLabel(blip.activeEndHour))")
                .font(.blip(size: 12))
                .foregroundStyle(BlipColor.textTertiary)
        }
    }
}
