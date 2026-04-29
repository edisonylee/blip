import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var auth: AuthService

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 16) {
                    HStack {
                        Text("blip")
                            .font(BlipTypography.wordmark)
                            .foregroundStyle(BlipColor.accent)
                        Spacer()
                        Button {
                            // TODO: + popover (screen-02)
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                    }
                    .padding(.horizontal, 20)

                    // Solo vlog card (parity with screen-01)
                    LogCard(
                        title: "vlog",
                        subtitle: "your space. each day runs 4am to 4am.",
                        progress: nil
                    )
                    .padding(.horizontal, 20)

                    // TODO: §4.2 live group cards rendered here

                    Spacer()

                    // Camera/logs toggle (screen-01)
                    HStack(spacing: 4) {
                        Capsule()
                            .fill(Color.clear)
                            .overlay(Text("camera").foregroundStyle(.white.opacity(0.5)))
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .overlay(Text("logs").foregroundStyle(.white))
                    }
                    .frame(width: 160, height: 36)
                    .background(Color.white.opacity(0.06), in: Capsule())
                    .padding(.bottom, 12)
                }
                .padding(.top, 8)
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthService())
}
