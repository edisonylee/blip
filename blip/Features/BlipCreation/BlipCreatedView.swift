import SwiftUI

/// Screen-04 parity — group name, join code, "invite a friend →", "done →".
struct BlipCreatedView: View {
    let blip: Blip
    let onDone: () -> Void

    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                Text(blip.name)
                    .font(BlipTypography.title)
                    .foregroundStyle(BlipColor.textPrimary)

                HStack(spacing: 6) {
                    Text("#")
                        .foregroundStyle(BlipColor.textSecondary)
                    Text(blip.joinCode)
                        .font(.system(size: 18, weight: .regular, design: .monospaced))
                        .foregroundStyle(BlipColor.textPrimary)
                        .textSelection(.enabled)
                }
                .padding(.top, 4)

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
                Text("blip").font(BlipTypography.title).foregroundStyle(BlipColor.accent)
            }
        }
        .toolbarBackground(BlipColor.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [inviteShareText])
        }
    }

    private var inviteShareText: String {
        "join my blip \"\(blip.name)\" — code: \(blip.joinCode)"
    }
}

#Preview {
    NavigationStack {
        BlipCreatedView(
            blip: Blip(
                id: "1",
                name: "Friend blipchat # 1 :)",
                ownerUid: "u",
                members: ["u"],
                size: 4,
                joinCode: "c9kz6il",
                inviteUrl: nil,
                timezoneIdentifier: "America/New_York",
                createdAt: Date()
            ),
            onDone: {}
        )
    }
    .preferredColorScheme(.dark)
}
