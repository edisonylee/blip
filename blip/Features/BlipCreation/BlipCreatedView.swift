import SwiftUI

/// Screen-04 parity — group name, join code, "invite a friend →", "done →".
struct BlipCreatedView: View {
    let blip: Blip
    let onDone: () -> Void

    @EnvironmentObject private var auth: AuthService
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                Text(blip.name)
                    .font(BlipTypography.title)
                    .foregroundStyle(BlipColor.textPrimary)

                Text(blip.joinCode)
                    .font(.blip(size: 18, weight: .semibold))
                    .foregroundStyle(BlipColor.textSecondary)
                    .textSelection(.enabled)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("daily window")
                        .font(.blip(size: 11, weight: .semibold))
                        .foregroundStyle(BlipColor.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Text(scheduleText)
                        .font(BlipTypography.body)
                        .foregroundStyle(BlipColor.textSecondary)
                    Text(blip.timezoneIdentifier.replacingOccurrences(of: "_", with: " "))
                        .font(BlipTypography.caption)
                        .foregroundStyle(BlipColor.textTertiary)
                }

                Button { showShareSheet = true } label: {
                    HStack(spacing: 6) {
                        Text("invite a friend").underline()
                        Text("→")
                    }
                    .font(BlipTypography.body)
                    .foregroundStyle(BlipColor.textPrimary)
                }
                .padding(.top, 8)

                Button(action: onDone) {
                    HStack(spacing: 6) {
                        Text("done").underline()
                        Text("→")
                    }
                    .font(BlipTypography.body)
                    .foregroundStyle(BlipColor.textPrimary)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("created")
                    .font(BlipTypography.body)
                    .foregroundStyle(BlipColor.textPrimary)
            }
        }
        .toolbarBackground(BlipColor.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [inviteShareText])
        }
    }

    private var inviteShareText: String {
        InviteShare.text(blipName: blip.name, joinCode: blip.joinCode, referrerUid: currentUid)
    }

    private var scheduleText: String {
        if blip.activeStartHour == blip.activeEndHour {
            return "24 hours, starting at \(BlipHour.hourLabel(blip.activeStartHour))"
        }
        return "\(BlipHour.hourLabel(blip.activeStartHour)) to \(BlipHour.hourLabel(blip.activeEndHour))"
    }

    private var currentUid: String? {
        if case .signedIn(let uid) = auth.state { return uid }
        return nil
    }
}

#Preview {
    NavigationStack {
        BlipCreatedView(
            blip: Blip(
                id: "1",
                name: "Friend blipchat # 1 :)",
                ownerUid: "u",
                adminUids: ["u"], members: ["u"],
                size: 4,
                joinCode: "c9kz6il",
                inviteUrl: nil,
                timezoneIdentifier: "America/New_York",
                activeStartHour: 8,
                activeEndHour: 22,
                createdAt: Date()
            ),
            onDone: {}
        )
    }
    .preferredColorScheme(.dark)
}
