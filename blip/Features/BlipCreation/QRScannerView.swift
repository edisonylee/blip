import SwiftUI
import VisionKit

// MARK: - QR scanner (VisionKit DataScannerViewController, iOS 16+)

/// Presents the device camera and recognises QR codes. Calls `onScanned` with
/// the raw string value of the first code it detects, then stops scanning so
/// the same code doesn't fire multiple times.
///
/// Expected QR format for blip user codes: `blip://user/{handle}`
/// The caller is responsible for parsing the result.
struct QRScannerView: View {

    /// Called once with the raw string value of the detected QR code.
    let onScanned: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        Group {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                _DataScannerWrapper(onScanned: onScanned)
            } else {
                unavailableView
            }
        }
    }

    private var unavailableView: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 48))
                    .foregroundStyle(BlipColor.textTertiary)
                Text("camera not available")
                    .font(BlipTypography.body)
                    .foregroundStyle(BlipColor.textPrimary)
                Text("QR scanning requires camera access on a real device.")
                    .font(BlipTypography.caption)
                    .foregroundStyle(BlipColor.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button("go back", action: onCancel)
                    .blipSecondary()
                    .padding(.horizontal, 48)
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - UIViewControllerRepresentable wrapper

private struct _DataScannerWrapper: UIViewControllerRepresentable {
    let onScanned: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScanned: onScanned) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .fast,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    // MARK: Coordinator

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScanned: (String) -> Void
        private var didFire = false

        init(onScanned: @escaping (String) -> Void) {
            self.onScanned = onScanned
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !didFire else { return }
            if let item = addedItems.first, case .barcode(let barcode) = item {
                guard let value = barcode.payloadStringValue else { return }
                didFire = true
                dataScanner.stopScanning()
                Task { @MainActor in self.onScanned(value) }
            }
        }
    }
}

// MARK: - Handle extractor

extension QRScannerView {
    /// Extracts a @handle from a `blip://user/{handle}` QR string.
    /// Returns nil for unrecognised formats.
    static func extractHandle(from qrString: String) -> String? {
        guard let url = URL(string: qrString),
              url.scheme == "blip",
              url.host == "user"
        else { return nil }
        let path = url.pathComponents.filter { $0 != "/" }
        return path.first.map { Handle.normalize($0) }
    }
}
