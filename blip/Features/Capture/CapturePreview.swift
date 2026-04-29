import AVFoundation
import SwiftUI
import UIKit

/// SwiftUI wrapper for `AVCaptureVideoPreviewLayer`. Landscape 16:9, letterboxed in portrait UI.
struct CapturePreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect
        if #available(iOS 17, *) {
            view.previewLayer.connection?.videoRotationAngle = 0
        }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
