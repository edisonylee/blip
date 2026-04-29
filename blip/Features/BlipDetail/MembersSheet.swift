import SwiftUI

/// Member list with Block / Unblock actions. Shipping this with Phase A so the
/// App Store review can find the Block control even before clip cells render.
struct MembersSheet: View {
    let blip: Blip

    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var moderation: ModerationService
    @Environment(\.dismiss) private var dismiss

    @State private var actionError: String?

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("members")
                        .font(BlipTypography.wordmark)
                        .foregroundStyle(BlipColor.accent)
                    Spacer()
                    Button("done") { dismiss() }
                        .foregroundStyle(BlipColor.textPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                List {
                    ForEach(blip.members, id: \.self) { uid in
                        MemberRow(
                            uid: uid,
                            isMe: isMe(uid),
                            isBlocked: moderation.isBlocked(uid),
                            onBlock: { Task { await runBlock(uid) } },
                            onUnblock: { Task { await runUnblock(uid) } }
                        )
                        .listRowBackground(BlipColor.surface)
                        .listRowSeparatorTint(BlipColor.surfaceElevated)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                if let actionError {
                    Text(actionError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                }
            }
        }
    }

    private func isMe(_ uid: String) -> Bool {
        if case .signedIn(let me) = auth.state { return me == uid }
        return false
    }

    private func runBlock(_ uid: String) async {
        do { try await moderation.block(uid: uid); actionError = nil }
        catch { actionError = error.localizedDescription }
    }

    private func runUnblock(_ uid: String) async {
        do { try await moderation.unblock(uid: uid); actionError = nil }
        catch { actionError = error.localizedDescription }
    }
}

private struct MemberRow: View {
    let uid: String
    let isMe: Bool
    let isBlocked: Bool
    let onBlock: () -> Void
    let onUnblock: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(BlipColor.accent)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(uid.prefix(2)).uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(isMe ? "you" : "@\(uid.prefix(8))")
                    .foregroundStyle(BlipColor.textPrimary)
                if isBlocked {
                    Text("blocked")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            if !isMe {
                if isBlocked {
                    Button("unblock", action: onUnblock)
                        .foregroundStyle(BlipColor.textPrimary)
                } else {
                    Menu {
                        Button("block @\(uid.prefix(8))", role: .destructive, action: onBlock)
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(BlipColor.textTertiary)
                            .padding(8)
                            .contentShape(Rectangle())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
