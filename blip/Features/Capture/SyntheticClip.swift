#if DEBUG
import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import UIKit

/// Generates a real 2-second .mov on the simulator so the upload + Firestore path can be exercised
/// without a camera source. Solid-color frames + a "BLIP" overlay so it's visually distinct.
enum SyntheticClip {
    static func generate(duration: TimeInterval = CaptureSession.clipDuration) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("blip-sim-\(UUID().uuidString).mov")

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)

        // Landscape 16:9 to match the real capture path (CaptureSession uses
        // videoRotationAngle = 0 = native sensor landscape).
        let width = 1280
        let height = 720

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false

        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ]
        let adapter = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: attrs
        )
        guard writer.canAdd(input) else { throw NSError(domain: "SyntheticClip", code: -1) }
        writer.add(input)

        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "SyntheticClip", code: -2)
        }
        writer.startSession(atSourceTime: .zero)

        let fps: Int32 = 30
        let frameCount = Int(duration * Double(fps))

        for i in 0..<frameCount {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 5_000_000) }

            guard let buffer = makePixelBuffer(width: width, height: height, frameIndex: i, total: frameCount) else {
                continue
            }
            let time = CMTime(value: CMTimeValue(i), timescale: CMTimeScale(fps))
            adapter.append(buffer, withPresentationTime: time)
        }

        input.markAsFinished()
        await writer.finishWriting()
        if let err = writer.error { throw err }
        return url
    }

    private static func makePixelBuffer(width: Int, height: Int, frameIndex: Int, total: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let pb = buffer else { return nil }

        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }

        guard let base = CVPixelBufferGetBaseAddress(pb) else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: base,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return nil }

        // Animate hue across the clip so frames are visibly distinct.
        let progress = Double(frameIndex) / Double(max(1, total - 1))
        let hue = CGFloat(progress)
        let bgColor = UIColor(hue: hue, saturation: 0.6, brightness: 0.25, alpha: 1.0).cgColor
        context.setFillColor(bgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let label = "BLIP \(frameIndex + 1)/\(total)"
        let attrString = NSAttributedString(string: label, attributes: [
            .font: UIFont.systemFont(ofSize: 60, weight: .heavy),
            .foregroundColor: UIColor.white,
        ])
        UIGraphicsPushContext(context)
        let size = attrString.size()
        attrString.draw(at: CGPoint(x: (CGFloat(width) - size.width) / 2,
                                    y: (CGFloat(height) - size.height) / 2))
        UIGraphicsPopContext()

        return pb
    }
}
#endif
