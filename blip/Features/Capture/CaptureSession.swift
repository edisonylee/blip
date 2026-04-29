import AVFoundation
import Foundation
import OSLog

private let log = Logger(subsystem: "app.blip.ios", category: "CaptureSession")

/// Wraps `AVCaptureSession` for recording clips up to `clipDuration` seconds.
///
/// Lifecycle:
///   1. `requestPermissions()` — call from a user-initiated tap (App Store policy).
///   2. `configure()` — sets up inputs/outputs on the session queue.
///   3. `start()` — begin running so the preview layer shows live feed.
///   4. `record()` — async, returns the file URL when the user stops or the cap is reached.
///   5. `stopRecording()` — call to end an in-progress recording early.
///   6. `stop()` — tear down when leaving the screen.
///
/// All `AVCaptureSession` mutation happens on `sessionQueue`, never on the main thread.
@MainActor
final class CaptureSession: ObservableObject {
    enum State: Equatable {
        case idle
        case denied
        case unavailable        // simulator / no camera hardware
        case ready
        case recording
        case error(String)
    }

    @Published private(set) var state: State = .idle

    /// Seconds elapsed since the current recording started. 0 when not recording.
    @Published private(set) var recordingElapsed: TimeInterval = 0

    /// True when configure() couldn't find a camera and we're in DEBUG. record() will then
    /// produce a synthetic clip so the upload + Firestore path remains testable.
    @Published private(set) var useSynthetic = false

    /// Exposed for `CapturePreview` to attach `AVCaptureVideoPreviewLayer`. Read-only externally.
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "app.blip.ios.capture", qos: .userInitiated)
    private let movieOutput = AVCaptureMovieFileOutput()
    private let recordingDelegate = MovieRecordingDelegate()
    private var elapsedTask: Task<Void, Never>?

    /// Maximum clip length. Single source of truth — SyntheticClip, ClipUploader, and UI all read this.
    static let clipDuration: TimeInterval = 2.0

    // MARK: - Permissions (call from a user-initiated event only)

    func requestPermissions() async -> Bool {
        let videoOK = await ensureAuth(for: .video)
        let audioOK = await ensureAuth(for: .audio)
        if !videoOK || !audioOK {
            state = .denied
            return false
        }
        return true
    }

    private func ensureAuth(for type: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: type) {
        case .authorized: return true
        case .denied, .restricted: return false
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: type)
        @unknown default: return false
        }
    }

    // MARK: - Configuration

    func configure() async {
        guard state != .recording else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [self] in
                session.beginConfiguration()
                defer { session.commitConfiguration() }

                session.sessionPreset = .high

                // Front camera (selfie). Fall back to back if missing. nil on simulator.
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                    ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                    ?? AVCaptureDevice.default(for: .video)
                guard let device else {
                    #if DEBUG
                    log.notice("no camera device — DEBUG synthetic-clip fallback enabled")
                    Task { @MainActor in
                        self.useSynthetic = true
                        self.state = .ready
                    }
                    #else
                    Task { @MainActor in self.state = .unavailable }
                    log.notice("no camera device")
                    #endif
                    cont.resume()
                    return
                }

                // Remove any prior inputs/outputs (idempotent re-configure).
                for input in session.inputs { session.removeInput(input) }
                for output in session.outputs { session.removeOutput(output) }

                do {
                    let videoInput = try AVCaptureDeviceInput(device: device)
                    if session.canAddInput(videoInput) { session.addInput(videoInput) }

                    if let audio = AVCaptureDevice.default(for: .audio) {
                        let audioInput = try AVCaptureDeviceInput(device: audio)
                        if session.canAddInput(audioInput) { session.addInput(audioInput) }
                    }

                    if session.canAddOutput(movieOutput) {
                        session.addOutput(movieOutput)
                    }

                    // Landscape 16:9 framing — phone held in portrait, captured frame is landscape.
                    if let connection = movieOutput.connection(with: .video) {
                        if #available(iOS 17, *) {
                            connection.videoRotationAngle = 0  // landscape right (native sensor)
                        }
                        if connection.isVideoMirroringSupported {
                            connection.isVideoMirrored = device.position == .front
                        }
                    }

                    Task { @MainActor in self.state = .ready }
                } catch {
                    log.error("configure failed: \(error.localizedDescription, privacy: .public)")
                    Task { @MainActor in self.state = .error(error.localizedDescription) }
                }
                cont.resume()
            }
        }
    }

    // MARK: - Start / Stop

    func start() {
        // No-op in synthetic mode (session has no inputs/outputs configured).
        if useSynthetic { return }
        sessionQueue.async { [self] in
            guard !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stop() {
        elapsedTask?.cancel()
        if useSynthetic { return }
        sessionQueue.async { [self] in
            if movieOutput.isRecording { movieOutput.stopRecording() }
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Ends an in-progress recording early. The `record()` continuation resolves normally.
    func stopRecording() {
        guard state == .recording else { return }
        sessionQueue.async { [self] in
            if movieOutput.isRecording { movieOutput.stopRecording() }
        }
    }

    // MARK: - Recording

    /// Records a clip (up to `clipDuration` seconds) and returns the local file URL.
    /// The user can end it early by calling `stopRecording()`.
    func record() async throws -> URL {
        guard state == .ready else { throw CaptureError.notReady }
        state = .recording
        startElapsedTimer()

        #if DEBUG
        if useSynthetic {
            defer {
                elapsedTask?.cancel()
                Task { @MainActor in self.state = .ready; self.recordingElapsed = 0 }
            }
            // SyntheticClip.generate() runs as fast as the simulator can encode
            // (often <2s, sometimes >2s). Real recording is hard-capped at
            // clipDuration via movieOutput.maxRecordedDuration; mirror that here
            // so the UI doesn't sit on .recording until encoding finishes.
            let recordStart = Date()
            let url = try await SyntheticClip.generate()
            let elapsed = Date().timeIntervalSince(recordStart)
            let remaining = Self.clipDuration - elapsed
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
            return url
        }
        #endif

        let url = makeTempURL()

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
            recordingDelegate.completion = { [weak self] result in
                Task { @MainActor in
                    self?.elapsedTask?.cancel()
                    self?.elapsedTask = nil
                    self?.recordingElapsed = 0
                    self?.state = .ready
                    cont.resume(with: result)
                }
            }

            sessionQueue.async { [self] in
                movieOutput.maxRecordedDuration = CMTime(seconds: Self.clipDuration, preferredTimescale: 600)
                movieOutput.startRecording(to: url, recordingDelegate: recordingDelegate)
            }
        }
    }

    private func startElapsedTimer() {
        elapsedTask?.cancel()
        recordingElapsed = 0
        let start = Date()
        elapsedTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if Task.isCancelled { break }
                recordingElapsed = Date().timeIntervalSince(start)
            }
        }
    }

    private func makeTempURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("blip-\(UUID().uuidString).mov")
    }
}

enum CaptureError: LocalizedError {
    case notReady
    case recordingFailed(String)

    var errorDescription: String? {
        switch self {
        case .notReady: return "Camera isn't ready yet."
        case .recordingFailed(let msg): return "Recording failed: \(msg)"
        }
    }
}

private final class MovieRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    var completion: ((Result<URL, Error>) -> Void)?

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        defer { completion = nil }
        // `maxRecordedDuration` reports as an error with `errorRecordingMaxRecordableDurationReached` —
        // we treat that as success since we asked for exactly that cap.
        if let nsError = error as NSError?,
           nsError.domain == AVFoundationErrorDomain,
           nsError.code == AVError.maximumDurationReached.rawValue {
            completion?(.success(outputFileURL))
            return
        }
        if let error {
            completion?(.failure(CaptureError.recordingFailed(error.localizedDescription)))
            return
        }
        completion?(.success(outputFileURL))
    }
}
