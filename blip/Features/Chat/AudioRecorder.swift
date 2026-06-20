import AVFoundation
import Foundation

/// AVAudioRecorder wrapper.  Publishes live metering bars for the animated
/// waveform and produces a 30-bar normalised waveform on stop for storage.
@MainActor
final class AudioRecorder: ObservableObject {

    // MARK: - Published

    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    /// Live spectrum bars — 30 values normalised 0…1, updated every 0.08 s.
    @Published private(set) var liveBars: [CGFloat] = Array(repeating: 0.05, count: 30)

    // MARK: - Private

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var startDate: Date?
    private(set) var recordingURL: URL?

    // Collected metering samples → averaged into 30 bars on stop.
    private var meterSamples: [Float] = []

    // MARK: - Permissions

    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    // MARK: - Start

    func start() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("blip-audio-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        guard let rec = try? AVAudioRecorder(url: url, settings: settings) else { return }
        rec.isMeteringEnabled = true
        rec.prepareToRecord()
        rec.record()

        recorder = rec
        recordingURL = url
        meterSamples = []
        startDate = Date()
        isRecording = true

        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    // MARK: - Stop → returns (localURL, duration, 30-bar waveform)

    func stop() -> (URL, TimeInterval, [Float])? {
        guard let rec = recorder, let url = recordingURL else { return nil }
        timer?.invalidate(); timer = nil
        rec.stop()
        let duration = rec.currentTime
        isRecording = false
        elapsed = 0

        // Produce 30 bars by averaging collected samples into equal buckets.
        let bars = reduce(meterSamples, to: 30)
        return (url, duration, bars)
    }

    // MARK: - Cancel

    func cancel() {
        timer?.invalidate(); timer = nil
        recorder?.stop()
        recorder?.deleteRecording()
        recorder = nil
        recordingURL = nil
        isRecording = false
        elapsed = 0
        liveBars = Array(repeating: 0.05, count: 30)
        meterSamples = []
    }

    // MARK: - Private helpers

    private func tick() {
        guard let rec = recorder, rec.isRecording else { return }
        rec.updateMeters()
        elapsed = rec.currentTime

        // averagePower is dB in range ≈ −160…0; normalise to 0…1
        let db = rec.averagePower(forChannel: 0)
        let norm = CGFloat(max(0, (db + 60) / 60)).clamped(to: 0...1)

        // Shift left, push new sample on the right
        var bars = liveBars
        bars.removeFirst()
        bars.append(max(0.05, norm))
        liveBars = bars

        meterSamples.append(Float(norm))
    }

    /// Average `samples` into `count` equal buckets.
    private func reduce(_ samples: [Float], to count: Int) -> [Float] {
        guard !samples.isEmpty else {
            return (0..<count).map { _ in Float.random(in: 0.15...0.6) }
        }
        let bucket = max(1, samples.count / count)
        return (0..<count).map { i in
            let slice = samples[(i * bucket)..<min((i + 1) * bucket, samples.count)]
            return slice.reduce(0, +) / Float(slice.count)
        }
    }
}

extension Comparable {
    fileprivate func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
