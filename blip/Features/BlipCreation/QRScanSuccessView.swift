import SwiftUI

/// 3-D card-flip overlay shown after a successful QR scan adds a user.
/// Front face = faint QR pattern; back face = green checkmark + handle.
/// Auto-dismisses after 2.2 s.
struct QRScanSuccessView: View {
    let handle: String
    let onDismiss: () -> Void

    @State private var rotationY: Double = 0
    @State private var opacity: Double  = 0

    private var showBack: Bool { rotationY >= 90 }

    var body: some View {
        ZStack {
            // Dim backdrop
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .opacity(opacity)
                .onTapGesture { dismiss() }

            // Card
            ZStack {
                if !showBack { frontFace } else { backFace }
            }
            .frame(width: 240, height: 280)
            .rotation3DEffect(
                .degrees(rotationY),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.6
            )
            .opacity(opacity)
        }
        .onAppear { start() }
    }

    // MARK: - Faces

    private var frontFace: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white)
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 80, weight: .ultraLight))
                        .foregroundStyle(BlipColor.textTertiary)
                    Text("scanning…")
                        .font(.blip(size: 13))
                        .foregroundStyle(BlipColor.textTertiary)
                }
            }
            .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
    }

    private var backFace: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hex: 0x6EE7B7), Color(hex: 0x059669)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                VStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.25)).frame(width: 80, height: 80)
                        Image(systemName: "checkmark")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(spacing: 4) {
                        Text("added!")
                            .font(.blip(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                        Text("@\(handle)")
                            .font(.blip(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            // Mirror the back face so text reads correctly after flip
            .scaleEffect(x: -1)
            .shadow(color: Color(hex: 0x059669).opacity(0.4), radius: 24, x: 0, y: 8)
    }

    // MARK: - Animation

    private func start() {
        // Fade in
        withAnimation(.easeOut(duration: 0.25)) { opacity = 1 }
        // Flip to back face
        withAnimation(.spring(response: 0.7, dampingFraction: 0.78).delay(0.3)) {
            rotationY = 180
        }
        // Auto-dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { dismiss() }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.2)) { opacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onDismiss() }
    }
}
