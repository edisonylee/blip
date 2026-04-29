import SwiftUI
import AVFoundation

/// Screen-08 parity placeholder — AVFoundation pipeline lands in Phase B.
/// Will need a UIViewRepresentable wrapper for AVCaptureVideoPreviewLayer.
///
/// APP STORE — permission timing:
/// `AVCaptureDevice.requestAccess(for: .video)` and the audio equivalent MUST be
/// called from the user-initiated record-button tap handler (or a Task it spawns).
/// Never request permission from `.onAppear`, `init`, or anywhere on app launch —
/// Apple flags pre-emptive permission prompts and rejects.
struct CaptureView: View {
    var body: some View {
        Text("capture — Phase B")
            .foregroundStyle(BlipColor.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BlipColor.background)
    }
}
