import SwiftUI

/// Screen-08 parity placeholder — AVFoundation pipeline lands in Phase B.
/// Will need a UIViewRepresentable wrapper for AVCaptureVideoPreviewLayer.
struct CaptureView: View {
    var body: some View {
        Text("capture — Phase B")
            .foregroundStyle(BlipColor.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BlipColor.background)
    }
}
