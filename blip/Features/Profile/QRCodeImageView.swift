import CoreImage
import SwiftUI

// MARK: - QR code image view

/// Generates a QR code from `data` and renders it inside a white square.
/// An optional `centerURL` is overlaid in the exact centre — "H" (high)
/// error-correction means up to 30 % of modules can be obscured by the photo
/// without losing decodability.
///
/// **Why the background task?**
/// SwiftUI's `.task` modifier runs on the @MainActor. `CIContext.createCGImage`
/// is a synchronous, potentially-GPU-bound call that blocks the main thread and
/// can silently return nil in certain GPU contexts. We dispatch it to a
/// `Task.detached` (background thread) so the main thread stays responsive and
/// the CIContext is created off-screen where it is most reliable.
struct QRCodeImageView: View {
    let data: String
    /// URL of the image to render in the centre (profile photo).
    var centerURL: URL?
    /// Fallback initials shown when `centerURL` is nil or fails to load.
    /// Pass the first 1-2 letters of the user's handle.
    var centerInitials: String? = nil
    /// Diameter of the rendered square.
    var size: CGFloat = 200
    private let centerRatio: CGFloat = 0.22

    @State private var qrImage: UIImage?

    var body: some View {
        ZStack {
            // White backing so dark QR modules are always readable.
            Rectangle()
                .fill(Color.white)
                .frame(width: size, height: size)

            if let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none) // never blur pixel-art QR modules
                    .resizable()
                    .scaledToFit()        // fit (not fill) — never clip a module
                    .frame(width: size, height: size)
            }

            // Centre overlay — photo if available, otherwise initials gradient circle
            let overlaySize = size * centerRatio
            ZStack {
                if let url = centerURL {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            // Image loading or failed — show initials as fallback
                            initialsCircle(diameter: overlaySize)
                        }
                    }
                } else {
                    // No URL at all — always show initials
                    initialsCircle(diameter: overlaySize)
                }
            }
            .frame(width: overlaySize, height: overlaySize)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 3))
            .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.075, style: .continuous))
        // Re-generate whenever the encoded string changes.
        .task(id: data) {
            // Dispatch to a background thread so CIContext GPU work never
            // blocks the main actor or silently fails in a main-thread GPU
            // context.
            let generated = await Task.detached(priority: .userInitiated) {
                Self.generateQR(from: data)
            }.value
            qrImage = generated
        }
    }

    // MARK: - Initials circle (shown when no photo)

    /// Gradient circle with the user's initials — used as the QR centre overlay
    /// when no profile photo is available.
    @ViewBuilder
    private func initialsCircle(diameter: CGFloat) -> some View {
        ZStack {
            // Rose-to-lavender gradient matching the app accent
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xFCA5A5), Color(hex: 0xF43F5E)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            if let letters = centerInitials, !letters.isEmpty {
                Text(letters)
                    .font(.system(size: diameter * 0.40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Generation (static → callable from Task.detached)

    /// Builds a `UIImage` for `string` using CoreImage's QR generator.
    /// Uses the string-based filter API (more portable than the typed Swift
    /// overlay) and forces `.up` orientation to prevent the CG→UIKit
    /// coordinate-flip that causes upside-down codes.
    private static func generateQR(from string: String) -> UIImage? {
        guard
            let filter = CIFilter(name: "CIQRCodeGenerator"),
            let data = string.data(using: .utf8)
        else { return nil }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // high — 30 % recoverable

        guard let raw = filter.outputImage else { return nil }

        // Scale up so each module renders as multiple pixels on retina screens.
        let scale: CGFloat = 12
        let scaled = raw.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        // Software renderer avoids GPU-context failures (e.g. on background
        // threads that don't own a Metal context).
        let ctx = CIContext(options: [.useSoftwareRenderer: true])
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }

        // Explicit `.up` orientation fixes the CoreImage Y-up ↔ UIKit Y-down
        // coordinate difference that otherwise flips the QR code vertically.
        return UIImage(cgImage: cg, scale: 1.0, orientation: .up)
    }
}

// MARK: - Tappable card (profile page)

struct QRCodeCard: View {
    let handle: String
    let photoURL: URL?

    @State private var expanded = false

    private var qrData: String { "blip://user/\(handle)" }
    private var initials: String { QRCodeCard.initials(from: handle) }

    var body: some View {
        Button { expanded = true } label: {
            VStack(spacing: 14) {
                QRCodeImageView(data: qrData, centerURL: photoURL, centerInitials: initials, size: 160)
                    .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 4)

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
            QRFullScreenView(handle: handle, photoURL: photoURL, initials: initials)
        }
    }

    // MARK: - Initials helper (shared with QRFullScreenView)

    /// Derives 1–2 uppercase initials from a handle.
    /// Splits on `_` and `.` to handle "john_doe" → "JD"; single-word
    /// handles like "johndoe" use the first two letters → "JO".
    static func initials(from handle: String) -> String {
        let segments = handle
            .components(separatedBy: CharacterSet(charactersIn: "_."))
            .map { $0.filter(\.isLetter) }
            .filter { !$0.isEmpty }
        if segments.count >= 2 {
            return segments.prefix(2)
                .compactMap { $0.first.map { String($0).uppercased() } }
                .joined()
        }
        return String(handle.filter(\.isLetter).prefix(2)).uppercased()
    }
}

// MARK: - Full-screen modal

struct QRFullScreenView: View {
    let handle: String
    let photoURL: URL?
    let initials: String
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
                    QRCodeImageView(data: qrData, centerURL: photoURL, centerInitials: initials, size: 260)
                        .shadow(color: .black.opacity(0.14), radius: 16, x: 0, y: 6)

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
