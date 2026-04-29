import AVKit
import SwiftUI

/// Today's blip view. Each hour is rendered as a `MemberGrid` mirroring the
/// server-side export composition: stable seat positions per `blip.members`
/// order, missing posters fill with a black cell on past hours, and unfilled
/// member capacity surfaces "invite a friend" cells in the same grid.
struct BlipDetailView: View {
    let blip: Blip

    @EnvironmentObject private var auth: AuthService
    @StateObject private var clips = ClipsRepository()
    @StateObject private var nudges = NudgeService()
    @StateObject private var profiles = UserProfilesRepository()

    @State private var showShareSheet = false
    @State private var showInviteSheet = false
    @State private var showMembers = false
    @State private var showCapture = false
    @State private var captionEditingClip: BlipClip?
    @State private var selectedHourOverride: Int?
    @State private var pendingNudgeeUid: String?

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
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
                        isCurrentHour: selectedHour == currentHour,
                        onRecord: { showCapture = true },
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
            profiles.observe(uids: blip.members)
        }
        .onChange(of: blip.members) { _, new in
            profiles.observe(uids: new)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(blip.name)
                    .font(BlipTypography.body)
                    .foregroundStyle(BlipColor.textPrimary)
                    .lineLimit(1)
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    Button { showMembers = true } label: {
                        Image(systemName: "person.2")
                            .foregroundStyle(BlipColor.textPrimary)
                    }
                    NavigationLink {
                        ArchiveView(blip: blip)
                    } label: {
                        Image(systemName: "calendar")
                            .foregroundStyle(BlipColor.textPrimary)
                    }
                    NavigationLink {
                        ExportView(blip: blip)
                    } label: {
                        Image(systemName: "film")
                            .foregroundStyle(BlipColor.textPrimary)
                    }
                    Button { showShareSheet = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(BlipColor.textPrimary)
                    }
                    NavigationLink {
                        ChatView(blipId: blip.id)
                    } label: {
                        Image(systemName: "bubble.right")
                            .foregroundStyle(BlipColor.textPrimary)
                    }
                }
            }
        }
        .toolbarBackground(BlipColor.background, for: .navigationBar)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [inviteShareText])
        }
        .sheet(isPresented: $showInviteSheet) {
            ShareSheet(activityItems: [inviteShareText])
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
        Calendar.current.component(.hour, from: Date())
    }

    private var selectedHour: Int {
        selectedHourOverride ?? currentHour
    }

    /// Slider nodes for today: every recorded hour plus the current hour,
    /// sorted in chronological order anchored to the 4AM blip-day boundary.
    /// With no past recordings the slider degenerates to a single node (now).
    private var todayHours: [Int] {
        let recorded = Set(clips.clipsByHour.keys)
        let nodes = recorded.union([currentHour])
        return nodes.sorted { lhs, rhs in
            ((lhs - 4 + 24) % 24) < ((rhs - 4 + 24) % 24)
        }
    }
}
