import SwiftUI

/// Full-screen launch splash — shows the blip wordmark with a spring
/// entrance, holds for a beat, then fades out and calls `onFinished`.
struct SplashView: View {
    let onFinished: () -> Void

    @State private var opacity: Double = 0
    @State private var scale: CGFloat  = 0.78
    @State private var dotScale: CGFloat = 0

    var body: some View {
        ZStack {
            BlipColor.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 20) {
                // Animated icon ring
                ZStack {
                    Circle()
                        .fill(BlipColor.accentNeutral.opacity(0.10))
                        .frame(width: 110, height: 110)
                        .scaleEffect(dotScale)

                    Image(systemName: "sparkles")
                        .font(.system(size: 46, weight: .light))
                        .foregroundStyle(BlipColor.accentNeutral)
                }

                VStack(spacing: 6) {
                    Text("blip.")
                        .font(BlipTypography.title)
                        .foregroundStyle(BlipColor.textPrimary)
                        .tracking(-0.5)

                    Text("your day in 2 seconds")
                        .font(.blip(size: 14))
                        .foregroundStyle(BlipColor.textTertiary)
                }
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear { animate() }
    }

    private func animate() {
        // 1. Entrance
        withAnimation(.spring(response: 0.65, dampingFraction: 0.7)) {
            opacity = 1; scale = 1
        }
        withAnimation(.spring(response: 0.8, dampingFraction: 0.55).delay(0.15)) {
            dotScale = 1
        }
        // 2. Hold then exit
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.35)) { opacity = 0; scale = 1.06 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onFinished() }
        }
    }
}
