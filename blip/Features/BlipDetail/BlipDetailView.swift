import SwiftUI

/// Screen-07 parity — vertical hour-slot stack. Slice A: empty placeholders, capture
/// pipeline lands in Slice B. Hour count derived from blip.size; current hour shows "tap to capture".
struct BlipDetailView: View {
    let blip: Blip

    @EnvironmentObject private var auth: AuthService
    @State private var showShareSheet = false
    @State private var showMembers = false
    @State private var showCapture = false

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 8) {
                    // First slot is "you" — current hour, tap to capture
                    Button { showCapture = true } label: {
                        YourSlot(uidInitials: currentUserInitials)
                    }
                    .buttonStyle(.plain)

                    // Remaining slots — invite-a-friend placeholders for empty member seats
                    ForEach(0..<emptySeatCount, id: \.self) { _ in
                        InviteSlot()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 64)
            }

            VStack {
                Spacer()
                TodayPill()
                    .padding(.bottom, 12)
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
                HStack(spacing: 8) {
                    Button { showMembers = true } label: {
                        Image(systemName: "person.2")
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
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: ["join my blip \"\(blip.name)\" — code: \(blip.joinCode)"])
        }
        .sheet(isPresented: $showMembers) {
            MembersSheet(blip: blip)
        }
        .fullScreenCover(isPresented: $showCapture) {
            NavigationStack {
                CaptureView(blip: blip, onPosted: { showCapture = false })
            }
        }
    }

    private var emptySeatCount: Int {
        max(0, blip.size - blip.members.count)
    }

    private var currentUserInitials: String {
        guard case .signedIn(let uid) = auth.state else { return "?" }
        return String(uid.prefix(2)).uppercased()
    }
}

private struct YourSlot: View {
    let uidInitials: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BlipColor.surface)

            VStack(spacing: 12) {
                HStack {
                    Circle()
                        .fill(BlipColor.accent)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text(uidInitials)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.black)
                        )
                    Spacer()
                    Image(systemName: "ellipsis")
                        .foregroundStyle(BlipColor.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                Text(currentHourString)
                    .font(BlipTypography.clipTimestamp)
                    .foregroundStyle(BlipColor.textPrimary.opacity(0.4))

                Text("tap to capture")
                    .font(BlipTypography.body)
                    .foregroundStyle(BlipColor.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(BlipColor.surfaceElevated, in: Capsule())
                    .padding(.bottom, 16)
            }
        }
        .frame(height: 200)
    }

    private var currentHourString: String {
        let h = Calendar.current.component(.hour, from: Date())
        return String(format: "%02d:00", h)
    }
}

private struct InviteSlot: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BlipColor.surface)

            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundStyle(BlipColor.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(BlipColor.surfaceElevated, in: Circle())
                Text("invite a friend")
                    .font(BlipTypography.caption)
                    .foregroundStyle(BlipColor.textTertiary)
            }
        }
        .frame(height: 120)
    }
}

private struct TodayPill: View {
    var body: some View {
        Text("Today")
            .font(BlipTypography.caption)
            .foregroundStyle(BlipColor.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(BlipColor.surface, in: Capsule())
    }
}
