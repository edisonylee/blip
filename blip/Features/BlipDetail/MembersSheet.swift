import SwiftUI

/// Member list with Block / Unblock actions, plus owner-only drag-to-reorder.
/// The order of `blip.members` is the seat order used by the stitched export and
/// `MemberGrid`, so reordering here is visible everywhere on the next snapshot.
struct MembersSheet: View {
    let blip: Blip

    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var moderation: ModerationService
    @EnvironmentObject private var repo: BlipRepository
    @StateObject private var profiles = UserProfilesRepository()
    @Environment(\.dismiss) private var dismiss

    @State private var actionError: String?
    @State private var orderedMembers: [String]
    @State private var editMode: EditMode = .inactive

    init(blip: Blip) {
        self.blip = blip
        _orderedMembers = State(initialValue: blip.members)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                header

                if isOwner && editMode == .active {
                    Text("drag to reorder")
                        .font(.footnote)
                        .foregroundStyle(BlipColor.textTertiary)
                        .padding(.horizontal, Layout.horizontalPadding)
                }

                memberList

                if let actionError {
                    Text(actionError)
                        .font(.footnote)
                        .foregroundStyle(BlipColor.error)
                        .padding(.horizontal, Layout.horizontalPadding)
                }
            }
        }
        .environment(\.editMode, $editMode)
        .task(id: blip.id) { profiles.observe(uids: blip.members) }
        .onChange(of: blip.members) { _, new in
            // Stay in sync if a remote snapshot lands while the sheet is open.
            // Don't clobber an in-flight local reorder.
            if editMode != .active {
                orderedMembers = new
            }
            profiles.observe(uids: new)
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text("members")
                .font(BlipTypography.title)
                .tracking(BlipTypography.titleTracking)
                .foregroundStyle(BlipColor.textPrimary)
            Spacer()
            if isOwner {
                Button(editMode == .active ? "done" : "edit order") {
                    withAnimation { editMode = (editMode == .active) ? .inactive : .active }
                }
                .foregroundStyle(BlipColor.textPrimary)
                .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
            }
            Button("done") { dismiss() }
                .foregroundStyle(BlipColor.textPrimary)
                .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.top, Layout.headerTopPadding)
    }

    private var memberList: some View {
        List {
            ForEach(orderedMembers, id: \.self) { uid in
                MemberRow(
                    uid: uid,
                    displayName: profiles.displayName(for: uid),
                    initials: profiles.initials(for: uid),
                    isMe: isMe(uid),
                    isOwner: uid == blip.ownerUid,
                    isAdmin: blip.isAdmin(uid),
                    isBlocked: moderation.isBlocked(uid),
                    canManageAdmin: isOwner && uid != blip.ownerUid,
                    onBlock: { Task { await runBlock(uid) } },
                    onUnblock: { Task { await runUnblock(uid) } },
                    onMakeAdmin: { Task { await runSetAdmin(uid, grant: true) } },
                    onRemoveAdmin: { Task { await runSetAdmin(uid, grant: false) } }
                )
                .listRowBackground(BlipColor.surface)
                .listRowSeparatorTint(BlipColor.surfaceElevated)
            }
            .onMove(perform: isOwner ? moveMembers : nil)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Actions

    private func moveMembers(from source: IndexSet, to destination: Int) {
        let previous = orderedMembers
        orderedMembers.move(fromOffsets: source, toOffset: destination)
        let next = orderedMembers
        Task {
            do {
                try await repo.updateMemberOrder(blipId: blip.id, members: next)
                actionError = nil
            } catch {
                #if DEBUG
                print("updateMemberOrder failed: \(error.localizedDescription)")
                #endif
                actionError = error.localizedDescription
                orderedMembers = previous
            }
        }
    }

    private func runBlock(_ uid: String) async {
        do { try await moderation.block(uid: uid); actionError = nil }
        catch { actionError = error.localizedDescription }
    }

    private func runUnblock(_ uid: String) async {
        do { try await moderation.unblock(uid: uid); actionError = nil }
        catch { actionError = error.localizedDescription }
    }

    private func runSetAdmin(_ uid: String, grant: Bool) async {
        do { try await repo.setAdmin(blipId: blip.id, uid: uid, grant: grant); actionError = nil }
        catch { actionError = error.localizedDescription }
    }

    // MARK: - Helpers

    private func isMe(_ uid: String) -> Bool {
        if case .signedIn(let me) = auth.state { return me == uid }
        return false
    }

    private var isOwner: Bool {
        if case .signedIn(let me) = auth.state { return me == blip.ownerUid }
        return false
    }

    private enum Layout {
        static let sectionSpacing: CGFloat = 16
        static let horizontalPadding: CGFloat = 20
        static let headerTopPadding: CGFloat = 8
        static let minTapTarget: CGFloat = 44
    }
}

private struct MemberRow: View {
    let uid: String
    let displayName: String?
    let initials: String
    let isMe: Bool
    let isOwner: Bool
    let isAdmin: Bool
    let isBlocked: Bool
    let canManageAdmin: Bool
    let onBlock: () -> Void
    let onUnblock: () -> Void
    let onMakeAdmin: () -> Void
    let onRemoveAdmin: () -> Void

    var body: some View {
        HStack(spacing: Layout.rowSpacing) {
            Circle()
                .fill(BlipColor.surfaceElevated)
                .frame(width: Layout.avatarSize, height: Layout.avatarSize)
                .overlay(
                    Text(initials)
                        .font(.blip(size: Layout.avatarFontSize, weight: .bold))
                        .foregroundStyle(BlipColor.textPrimary)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(primaryLabel)
                        .foregroundStyle(BlipColor.textPrimary)
                    if isOwner {
                        Text("owner")
                            .font(.blip(size: 10, weight: .semibold))
                            .foregroundStyle(BlipColor.accentNeutral)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(BlipColor.accentNeutral.opacity(0.12),
                                        in: Capsule())
                    } else if isAdmin {
                        Text("admin")
                            .font(.blip(size: 10, weight: .semibold))
                            .foregroundStyle(BlipColor.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(BlipColor.surfaceElevated,
                                        in: Capsule())
                    }
                }
                if isBlocked {
                    Text("blocked")
                        .font(.caption)
                        .foregroundStyle(BlipColor.error)
                }
            }

            Spacer()

            if !isMe {
                if isBlocked {
                    Button("unblock", action: onUnblock)
                        .foregroundStyle(BlipColor.textPrimary)
                        .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
                } else {
                    Menu {
                        if canManageAdmin {
                            if isAdmin {
                                Button("remove admin", action: onRemoveAdmin)
                            } else {
                                Button("make admin", action: onMakeAdmin)
                            }
                            Divider()
                        }
                        Button("block \(blockLabel)", role: .destructive, action: onBlock)
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(BlipColor.textTertiary)
                            .padding(Layout.menuIconPadding)
                            .frame(minWidth: Layout.minTapTarget, minHeight: Layout.minTapTarget)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("more actions")
                }
            }
        }
        .padding(.vertical, Layout.rowVerticalPadding)
    }

    private var primaryLabel: String {
        if isMe { return "you" }
        return displayName ?? "member"
    }

    private var blockLabel: String {
        displayName ?? "this member"
    }

    private enum Layout {
        static let rowSpacing: CGFloat = 12
        static let avatarSize: CGFloat = 32
        static let avatarFontSize: CGFloat = 12
        static let rowVerticalPadding: CGFloat = 4
        static let menuIconPadding: CGFloat = 8
        static let minTapTarget: CGFloat = 44
    }
}
