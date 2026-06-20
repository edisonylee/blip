import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

/// Generates a QR code from `data` and renders it inside a white-background square.
/// An optional `centerURL` (AsyncImage) is overlaid in the exact center — use "H"
/// (high) error-correction so 30 % of the code can be obscured by the photo without
/// losing decodability.
struct QRCodeImageView: View {
    let data: String
    /// URL of the image to render in the center (profile photo, etc.). Pass nil to
    /// show a plain QR code.
    var centerURL: URL?
    /// Diameter of the entire view (QR code is square).
    var size: CGFloat = 200
    /// Diameter of the center photo overlay as a fraction of `size`.
    private let centerRatio: CGFloat = 0.22

    @State private var qrImage: UIImage?

    var body: some View {
        ZStack {
            // White background so dark QR modules are always readable.
            Rectangle()
                .fill(Color.white)
                .frame(width: size, height: size)

            if let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)   // keep pixels sharp, never blur
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
            }

            // Center photo overlay
            if let url = centerURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Circle().fill(Color(white: 0.85))
                    }
                }
                .frame(width: size * centerRatio, height: size * centerRatio)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 3))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.075, style: .continuous))
        .task(id: data) { qrImage = makeQR() }
    }

    private func makeQR() -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(data.utf8)
        filter.correctionLevel = "H"
        guard let raw = filter.outputImage else { return nil }
        // Scale so the output is crisp on @3× screens.
        let scale: CGFloat = 12
        let scaled = raw.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let ctx = CIContext(options: [.useSoftwareRenderer: false])
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - Full-screen expandable wrapper used on the profile page

struct QRCodeCard: View {
    let handle: String
    let photoURL: URL?

    @State private var expanded = false

    private var qrData: String { "blip://user/\(handle)" }

    var body: some View {
        Button { expanded = true } label: {
            VStack(spacing: 14) {
                QRCodeImageView(data: qrData, centerURL: photoURL, size: 160)
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)

                VStack(spacing: 3) {
                    Text("your blip code")
                        .font(.blip(size: 13, weight: .semibold))
                        .foregroundStyle(BlipColor.textPrimary)
                    Text("others scan this to add you")
                        .font(.blip(size: 11))
                        .foregroundStyle(BlipColor.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $expanded) {
            QRFullScreenView(handle: handle, photoURL: photoURL)
        }
    }
}

// MARK: - Full-screen QR modal

private struct QRFullScreenView: View {
    let handle: String
    let photoURL: URL?
    @Environment(\.dismiss) private var dismiss

    private var qrData: String { "blip://user/\(handle)" }

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            VStack(spacing: 28) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(BlipColor.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(BlipColor.surface, in: Circle())
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                VStack(spacing: 20) {
                    QRCodeImageView(data: qrData, centerURL: photoURL, size: 260)
                        .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 6)

                    VStack(spacing: 4) {
                        Text("@\(handle)")
                            .font(BlipTypography.body)
                            .foregroundStyle(BlipColor.textPrimary)
                        Text("scan to add me to your blip")
                            .font(.blip(size: 13))
                            .foregroundStyle(BlipColor.textTertiary)
                    }
                }

                Spacer()
            }
        }
        .presentationDetents([.large])
    }
}
